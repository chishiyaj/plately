"""
database.py — Dual-mode: PostgreSQL in production (Render), SQLite locally.
Set DATABASE_URL env var to use PostgreSQL. Without it, falls back to SQLite.
"""

import os
import threading
import logging

logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "")  # Set by Render automatically

# ── Detect mode ───────────────────────────────────────────────────────────────
USE_PG = bool(DATABASE_URL)

if USE_PG:
    import psycopg2
    import psycopg2.extras
    from urllib.parse import urlparse

    # Render gives postgres:// but psycopg2 needs postgresql://
    _pg_url = DATABASE_URL.replace("postgres://", "postgresql://", 1)

    _pg_pool_lock = threading.Lock()
    _pg_local = threading.local()

    def get_db():
        if not getattr(_pg_local, "conn", None) or _pg_local.conn.closed:
            _pg_local.conn = psycopg2.connect(_pg_url, cursor_factory=psycopg2.extras.RealDictCursor)
            _pg_local.conn.autocommit = False
        return _pg_local.conn

    def _ph(n=1):
        """Return n positional placeholders for PG: %s, %s, ..."""
        return ", ".join(["%s"] * n)

    PLACEHOLDER = "%s"

else:
    import sqlite3

    DB_PATH = os.path.join(os.path.dirname(__file__), "db", "plately.db")
    _local = threading.local()

    def get_db():
        if not getattr(_local, "conn", None):
            os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
            conn = sqlite3.connect(DB_PATH, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA foreign_keys=ON")
            conn.execute("PRAGMA cache_size=-4000")
            _local.conn = conn
        return _local.conn

    PLACEHOLDER = "?"


# ── Unified query helpers ─────────────────────────────────────────────────────

def query(sql: str, params: tuple = ()) -> list[dict]:
    """Run SELECT, return list of dicts."""
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        rows = cur.fetchall()
        return [dict(r) for r in rows]
    except Exception as e:
        logger.error("DB query error: %s | sql=%s", e, sql)
        if USE_PG:
            conn.rollback()
        raise


def execute(sql: str, params: tuple = ()) -> int:
    """Run INSERT/UPDATE/DELETE, return lastrowid (SQLite) or id (PG if RETURNING id)."""
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        conn.commit()
        if USE_PG:
            # If query ends with RETURNING id, fetch it
            try:
                row = cur.fetchone()
                return row["id"] if row else 0
            except Exception:
                return 0
        else:
            return cur.lastrowid
    except Exception as e:
        conn.rollback()
        logger.error("DB execute error: %s | sql=%s", e, sql)
        raise


def executemany(sql: str, params_list: list) -> None:
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.executemany(sql, params_list)
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error("DB executemany error: %s", e)
        raise


# ── Schema ────────────────────────────────────────────────────────────────────

def _create_tables():
    conn = get_db()
    cur = conn.cursor()

    if USE_PG:
        statements = [
            """CREATE TABLE IF NOT EXISTS ingredients (
                id   SERIAL PRIMARY KEY,
                name TEXT UNIQUE NOT NULL
            )""",
            """CREATE TABLE IF NOT EXISTS recipes (
                id           SERIAL PRIMARY KEY,
                name         TEXT NOT NULL,
                cook_time    TEXT NOT NULL,
                difficulty   TEXT NOT NULL,
                instructions TEXT NOT NULL,
                tags         TEXT DEFAULT ''
            )""",
            """CREATE TABLE IF NOT EXISTS recipe_ingredients (
                recipe_id     INTEGER NOT NULL REFERENCES recipes(id),
                ingredient_id INTEGER NOT NULL REFERENCES ingredients(id),
                amount        TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (recipe_id, ingredient_id)
            )""",
            """CREATE TABLE IF NOT EXISTS nutrition (
                recipe_id INTEGER PRIMARY KEY REFERENCES recipes(id),
                calories  INTEGER NOT NULL,
                protein   INTEGER NOT NULL,
                carbs     INTEGER NOT NULL,
                fat       INTEGER NOT NULL
            )""",
            """CREATE TABLE IF NOT EXISTS history (
                id               SERIAL PRIMARY KEY,
                user_id          TEXT NOT NULL DEFAULT 'default',
                action_type      TEXT NOT NULL,
                ingredient_names TEXT NOT NULL,
                recipe_count     INTEGER NOT NULL DEFAULT 0,
                timestamp        TIMESTAMPTZ DEFAULT NOW()
            )""",
            """CREATE TABLE IF NOT EXISTS favorites (
                id        SERIAL PRIMARY KEY,
                user_id   TEXT NOT NULL DEFAULT 'default',
                recipe_id INTEGER NOT NULL REFERENCES recipes(id),
                UNIQUE (user_id, recipe_id)
            )""",
            "CREATE INDEX IF NOT EXISTS idx_history_user ON history(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_history_ts ON history(timestamp)",
        ]
        for stmt in statements:
            cur.execute(stmt)
    else:
        cur.executescript("""
            CREATE TABLE IF NOT EXISTS ingredients (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL
            );
            CREATE TABLE IF NOT EXISTS recipes (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                name         TEXT NOT NULL,
                cook_time    TEXT NOT NULL,
                difficulty   TEXT NOT NULL,
                instructions TEXT NOT NULL,
                tags         TEXT DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS recipe_ingredients (
                recipe_id     INTEGER NOT NULL,
                ingredient_id INTEGER NOT NULL,
                amount        TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (recipe_id, ingredient_id),
                FOREIGN KEY (recipe_id)     REFERENCES recipes(id),
                FOREIGN KEY (ingredient_id) REFERENCES ingredients(id)
            );
            CREATE TABLE IF NOT EXISTS nutrition (
                recipe_id INTEGER PRIMARY KEY,
                calories  INTEGER NOT NULL,
                protein   INTEGER NOT NULL,
                carbs     INTEGER NOT NULL,
                fat       INTEGER NOT NULL,
                FOREIGN KEY (recipe_id) REFERENCES recipes(id)
            );
            CREATE TABLE IF NOT EXISTS history (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id          TEXT NOT NULL DEFAULT 'default',
                action_type      TEXT NOT NULL,
                ingredient_names TEXT NOT NULL,
                recipe_count     INTEGER NOT NULL DEFAULT 0,
                timestamp        DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS favorites (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id   TEXT NOT NULL DEFAULT 'default',
                recipe_id INTEGER NOT NULL,
                UNIQUE (user_id, recipe_id),
                FOREIGN KEY (recipe_id) REFERENCES recipes(id)
            );
            CREATE INDEX IF NOT EXISTS idx_history_user   ON history(user_id);
            CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);
            CREATE INDEX IF NOT EXISTS idx_history_ts     ON history(timestamp);
        """)

    conn.commit()


# ── Seed data ─────────────────────────────────────────────────────────────────

def _seed():
    existing = query("SELECT COUNT(*) as c FROM recipes")
    if existing[0]["c"] > 0:
        return

    ph = PLACEHOLDER

    ingredients = [
        "chicken", "eggs", "rice", "garlic", "onion",
        "soy sauce", "ginger", "sesame oil", "cornstarch",
        "beef", "broccoli", "pasta", "tuna", "cheese",
        "tomato", "mixed vegetables", "shrimp", "butter",
        "olive oil", "salt", "pepper", "lemon",
        "tofu", "spinach", "cucumber", "bell pepper", "potato",
        "carrot", "mushroom", "salmon", "bread", "milk", "noodles",
        "pork", "cabbage", "flour", "sugar", "vinegar", "fish sauce",
        "coconut milk", "lime", "cilantro", "chili", "bacon",
    ]

    insert_ing = f"INSERT INTO ingredients (name) VALUES ({ph}) ON CONFLICT (name) DO NOTHING"
    if not USE_PG:
        insert_ing = f"INSERT OR IGNORE INTO ingredients (name) VALUES ({ph})"
    for ing in ingredients:
        execute(insert_ing, (ing,))

    recipes = [
        {"name":"Chicken Stir Fry","cook_time":"20 min","difficulty":"Easy","tags":"Asian,High-Protein",
         "instructions":"1. Slice chicken into strips and season.\n2. Mix soy sauce, sesame oil, cornstarch.\n3. Stir-fry chicken 3-4 min. Remove.\n4. Stir-fry vegetables 2-3 min.\n5. Return chicken, add sauce, toss, serve.",
         "nutrition":(420,38,32,12),"ingredients":[("chicken","200g"),("mixed vegetables","1.5 cups"),("soy sauce","2 tbsp"),("garlic","3 cloves"),("ginger","1 tsp"),("sesame oil","1 tbsp"),("cornstarch","1 tbsp")]},
        {"name":"Egg Fried Rice","cook_time":"15 min","difficulty":"Easy","tags":"Asian",
         "instructions":"1. Cook rice. Cool.\n2. Scramble eggs in wok. Remove.\n3. Fry garlic, onion.\n4. Add rice, soy sauce, toss.\n5. Return eggs, mix well, serve.",
         "nutrition":(380,22,55,9),"ingredients":[("rice","1 cup"),("eggs","3"),("garlic","2 cloves"),("onion","1 small"),("soy sauce","1 tbsp")]},
        {"name":"Tuna Pasta","cook_time":"18 min","difficulty":"Medium","tags":"Italian,High-Protein",
         "instructions":"1. Cook pasta al dente.\n2. Drain tuna, flake.\n3. Sauté garlic in olive oil.\n4. Add tomato, simmer 5 min.\n5. Toss pasta and tuna, serve.",
         "nutrition":(490,34,58,11),"ingredients":[("pasta","100g"),("tuna","150g"),("tomato","2"),("garlic","2 cloves"),("olive oil","1 tbsp")]},
        {"name":"Beef Bowl","cook_time":"25 min","difficulty":"Medium","tags":"High-Protein",
         "instructions":"1. Slice beef thin.\n2. Marinate in soy sauce, ginger.\n3. Cook rice.\n4. Sear beef 3-4 min.\n5. Serve over rice with garnish.",
         "nutrition":(550,45,42,18),"ingredients":[("beef","200g"),("rice","1 cup"),("soy sauce","2 tbsp"),("ginger","1 tsp"),("onion","1 small")]},
        {"name":"Veggie Omelette","cook_time":"10 min","difficulty":"Easy","tags":"Vegetarian,Low-Cal,High-Protein",
         "instructions":"1. Beat eggs with salt and pepper.\n2. Sauté onion, tomato.\n3. Pour eggs over veggies.\n4. Fold and cook 2 min.\n5. Serve with toast.",
         "nutrition":(310,24,18,14),"ingredients":[("eggs","3"),("tomato","1"),("onion","0.5"),("cheese","30g"),("butter","1 tsp")]},
        {"name":"Garlic Shrimp Pasta","cook_time":"22 min","difficulty":"Medium","tags":"Italian,High-Protein",
         "instructions":"1. Cook pasta.\n2. Sauté garlic in butter and olive oil.\n3. Add shrimp, cook 3 min each side.\n4. Toss with pasta and lemon juice.\n5. Season and serve.",
         "nutrition":(520,32,54,16),"ingredients":[("shrimp","200g"),("pasta","100g"),("garlic","4 cloves"),("butter","2 tbsp"),("lemon","0.5"),("olive oil","1 tbsp")]},
        {"name":"Tofu Scramble","cook_time":"12 min","difficulty":"Easy","tags":"Vegetarian,Low-Cal,High-Protein",
         "instructions":"1. Crumble tofu into a hot pan.\n2. Add garlic and onion, sauté 3 min.\n3. Season with soy sauce and pepper.\n4. Add spinach, cook 2 min until wilted.\n5. Serve with toast.",
         "nutrition":(280,22,18,10),"ingredients":[("tofu","200g"),("garlic","2 cloves"),("onion","0.5"),("soy sauce","1 tbsp"),("spinach","1 cup")]},
        {"name":"Salmon with Garlic Rice","cook_time":"25 min","difficulty":"Medium","tags":"High-Protein,Low-Cal",
         "instructions":"1. Season salmon with salt, pepper, lemon.\n2. Pan-sear salmon 4 min each side.\n3. Cook rice with garlic in butter.\n4. Plate rice, top with salmon.\n5. Squeeze lemon, serve.",
         "nutrition":(460,42,38,14),"ingredients":[("salmon","200g"),("rice","1 cup"),("garlic","3 cloves"),("butter","1 tbsp"),("lemon","0.5")]},
        {"name":"Pork Cabbage Stir Fry","cook_time":"18 min","difficulty":"Easy","tags":"Asian,High-Protein",
         "instructions":"1. Slice pork thin, marinate in soy sauce and ginger.\n2. Stir-fry pork on high heat 4 min.\n3. Add garlic and onion, cook 1 min.\n4. Add cabbage, toss until wilted.\n5. Season with fish sauce, serve over rice.",
         "nutrition":(390,30,28,13),"ingredients":[("pork","200g"),("cabbage","2 cups"),("garlic","3 cloves"),("ginger","1 tsp"),("soy sauce","2 tbsp"),("fish sauce","1 tbsp")]},
        {"name":"Bacon and Egg Toast","cook_time":"10 min","difficulty":"Easy","tags":"High-Protein",
         "instructions":"1. Fry bacon strips until crispy.\n2. Fry eggs sunny-side up in same pan.\n3. Toast bread until golden.\n4. Layer bacon and egg on toast.\n5. Season with pepper and serve.",
         "nutrition":(420,28,30,20),"ingredients":[("bacon","3 strips"),("eggs","2"),("bread","2 slices"),("butter","1 tsp"),("pepper","to taste")]},
        {"name":"Mushroom and Spinach Pasta","cook_time":"20 min","difficulty":"Easy","tags":"Vegetarian,Italian",
         "instructions":"1. Cook pasta al dente.\n2. Sauté garlic in olive oil.\n3. Add mushrooms, cook until golden.\n4. Add spinach, wilt 1 min.\n5. Toss with pasta, season and serve.",
         "nutrition":(410,18,62,10),"ingredients":[("pasta","100g"),("mushroom","150g"),("spinach","1 cup"),("garlic","3 cloves"),("olive oil","2 tbsp")]},
        {"name":"Coconut Milk Chicken","cook_time":"30 min","difficulty":"Medium","tags":"Asian,High-Protein",
         "instructions":"1. Sauté garlic, ginger, chili in oil.\n2. Add chicken pieces, brown 5 min.\n3. Pour in coconut milk, simmer 15 min.\n4. Add fish sauce and lime juice.\n5. Garnish with cilantro, serve with rice.",
         "nutrition":(480,40,22,24),"ingredients":[("chicken","200g"),("coconut milk","200ml"),("garlic","3 cloves"),("ginger","1 tsp"),("chili","1"),("fish sauce","1 tbsp"),("lime","0.5"),("cilantro","to taste")]},
        {"name":"Potato and Egg Hash","cook_time":"22 min","difficulty":"Easy","tags":"Vegetarian,High-Protein",
         "instructions":"1. Dice potatoes, boil 8 min until just tender.\n2. Pan-fry potatoes in oil until crispy.\n3. Add onion and bell pepper, cook 3 min.\n4. Crack eggs over hash, cover and cook 3 min.\n5. Season and serve hot.",
         "nutrition":(360,18,48,12),"ingredients":[("potato","2 medium"),("eggs","3"),("onion","1 small"),("bell pepper","0.5"),("olive oil","2 tbsp")]},
        {"name":"Spicy Tuna Rice Bowl","cook_time":"12 min","difficulty":"Easy","tags":"High-Protein,Low-Cal",
         "instructions":"1. Cook rice.\n2. Mix tuna with soy sauce, sesame oil, chili.\n3. Slice cucumber thinly.\n4. Assemble: rice base, tuna mix on top.\n5. Add cucumber, drizzle with lime.",
         "nutrition":(380,35,42,8),"ingredients":[("tuna","150g"),("rice","1 cup"),("cucumber","0.5"),("soy sauce","1 tbsp"),("sesame oil","1 tsp"),("chili","0.5"),("lime","0.5")]},
    ]

    for r in recipes:
        if USE_PG:
            rid = execute(
                f"INSERT INTO recipes (name, cook_time, difficulty, instructions, tags) VALUES ({ph},{ph},{ph},{ph},{ph}) RETURNING id",
                (r["name"], r["cook_time"], r["difficulty"], r["instructions"], r["tags"]),
            )
        else:
            rid = execute(
                f"INSERT INTO recipes (name, cook_time, difficulty, instructions, tags) VALUES ({ph},{ph},{ph},{ph},{ph})",
                (r["name"], r["cook_time"], r["difficulty"], r["instructions"], r["tags"]),
            )

        cal, pro, carb, fat = r["nutrition"]
        execute(
            f"INSERT INTO nutrition (recipe_id, calories, protein, carbs, fat) VALUES ({ph},{ph},{ph},{ph},{ph})",
            (rid, cal, pro, carb, fat),
        )
        for ing_name, amount in r["ingredients"]:
            row = query(f"SELECT id FROM ingredients WHERE name = {ph}", (ing_name,))
            if row:
                ing_id = row[0]["id"]
                if USE_PG:
                    execute(
                        f"INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount) VALUES ({ph},{ph},{ph}) ON CONFLICT DO NOTHING",
                        (rid, ing_id, amount),
                    )
                else:
                    execute(
                        f"INSERT OR IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, amount) VALUES ({ph},{ph},{ph})",
                        (rid, ing_id, amount),
                    )

    logger.info("Seeded %d recipes, %d ingredients", len(recipes), len(ingredients))


def init_db() -> None:
    _create_tables()
    _seed()
    logger.info("DB ready — mode: %s", "PostgreSQL" if USE_PG else "SQLite")
