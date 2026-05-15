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
    from psycopg2 import pool as pg_pool

    _pg_url = DATABASE_URL.replace("postgres://", "postgresql://", 1)
    _pool_lock = threading.Lock()
    _pg_pool_instance = None

    def _get_pg_pool():
        global _pg_pool_instance
        if _pg_pool_instance is None:
            with _pool_lock:
                if _pg_pool_instance is None:
                    _pg_pool_instance = pg_pool.ThreadedConnectionPool(
                        1, 5, _pg_url,
                        cursor_factory=psycopg2.extras.RealDictCursor,
                    )
        return _pg_pool_instance

    def get_db():
        """Return a pooled PG connection. Auto-recreates pool if Neon killed idle connections."""
        global _pg_pool_instance
        pool = _get_pg_pool()
        try:
            conn = pool.getconn()
            # Ping to verify the connection is alive — Neon drops idle connections after ~5 min
            conn.cursor().execute("SELECT 1")
            return conn
        except Exception:
            # Connection is dead — close the whole pool and recreate it fresh
            logger.warning("PG connection dead, recreating pool...")
            try:
                pool.closeall()
            except Exception:
                pass
            with _pool_lock:
                _pg_pool_instance = None
            return _get_pg_pool().getconn()

    def putconn(conn):
        try:
            _get_pg_pool().putconn(conn)
        except Exception:
            pass

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
    if USE_PG:
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute(sql, params)
            rows = cur.fetchall()
            conn.commit()
            return [dict(r) for r in rows]
        except Exception as e:
            conn.rollback()
            logger.error("DB query error: %s | sql=%s", e, sql)
            raise
        finally:
            putconn(conn)
    else:
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute(sql, params)
            rows = cur.fetchall()
            return [dict(r) for r in rows]
        except Exception as e:
            logger.error("DB query error: %s | sql=%s", e, sql)
            raise


def execute(sql: str, params: tuple = ()) -> int:
    if USE_PG:
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute(sql, params)
            conn.commit()
            try:
                row = cur.fetchone()
                return row["id"] if row else 0
            except Exception:
                return 0
        except Exception as e:
            conn.rollback()
            logger.error("DB execute error: %s | sql=%s", e, sql)
            raise
        finally:
            putconn(conn)
    else:
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute(sql, params)
            conn.commit()
            return cur.lastrowid
        except Exception as e:
            conn.rollback()
            logger.error("DB execute error: %s | sql=%s", e, sql)
            raise


def executemany(sql: str, params_list: list) -> None:
    if USE_PG:
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.executemany(sql, params_list)
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error("DB executemany error: %s", e)
            raise
        finally:
            putconn(conn)
    else:
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
    if USE_PG:
        conn = get_db()
        try:
            cur = conn.cursor()
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
                    tags         TEXT DEFAULT '',
                    image_url    TEXT DEFAULT ''
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
                    fat       INTEGER NOT NULL,
                    cost_php  INTEGER NOT NULL DEFAULT 0
                )""",
                """CREATE TABLE IF NOT EXISTS history (
                    id               SERIAL PRIMARY KEY,
                    user_id          TEXT NOT NULL DEFAULT 'default',
                    action_type      TEXT NOT NULL,
                    ingredient_names TEXT NOT NULL,
                    recipe_count     INTEGER NOT NULL DEFAULT 0,
                    calories_logged  INTEGER NOT NULL DEFAULT 0,
                    protein_logged   INTEGER NOT NULL DEFAULT 0,
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
                """CREATE TABLE IF NOT EXISTS ai_recipe_cache (
                    cache_key    TEXT PRIMARY KEY,
                    recipes_json TEXT NOT NULL,
                    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )""",
            ]
            for stmt in statements:
                cur.execute(stmt)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            putconn(conn)

        # Migration guards — run with advisory lock so only ONE worker executes
        # this at a time, preventing deadlocks on multi-worker startup.
        conn = get_db()
        try:
            cur = conn.cursor()
            cur.execute("SELECT pg_advisory_lock(987654321)")
            migrations = [
                "ALTER TABLE recipes ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT ''",
                "ALTER TABLE history ADD COLUMN IF NOT EXISTS calories_logged INTEGER NOT NULL DEFAULT 0",
                "ALTER TABLE history ADD COLUMN IF NOT EXISTS protein_logged INTEGER NOT NULL DEFAULT 0",
                "ALTER TABLE nutrition ADD COLUMN IF NOT EXISTS cost_php INTEGER NOT NULL DEFAULT 0",
                "ALTER TABLE history ADD COLUMN IF NOT EXISTS recipe_id INTEGER NOT NULL DEFAULT 0",
                "ALTER TABLE history ADD COLUMN IF NOT EXISTS recipe_name TEXT NOT NULL DEFAULT ''",
            ]
            for m in migrations:
                cur.execute(m)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            try:
                cur.execute("SELECT pg_advisory_unlock(987654321)")
                conn.commit()
            except Exception:
                pass
            putconn(conn)
    else:
        conn = get_db()
        cur = conn.cursor()
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
                tags         TEXT DEFAULT '',
                image_url    TEXT DEFAULT ''
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
                cost_php  INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (recipe_id) REFERENCES recipes(id)
            );
            CREATE TABLE IF NOT EXISTS history (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id          TEXT NOT NULL DEFAULT 'default',
                action_type      TEXT NOT NULL,
                ingredient_names TEXT NOT NULL,
                recipe_count     INTEGER NOT NULL DEFAULT 0,
                calories_logged  INTEGER NOT NULL DEFAULT 0,
                protein_logged   INTEGER NOT NULL DEFAULT 0,
                recipe_id        INTEGER NOT NULL DEFAULT 0,
                recipe_name      TEXT NOT NULL DEFAULT '',
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
            CREATE TABLE IF NOT EXISTS ai_recipe_cache (
                cache_key    TEXT PRIMARY KEY,
                recipes_json TEXT NOT NULL,
                created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
            );
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
        # Filipino pantry extras
        "pork belly", "bay leaf", "annatto", "banana blossom",
        "eggplant", "bitter melon", "kangkong", "sitaw",
        "tamarind", "miso paste", "dried fish", "peanut butter",
        "oxtail", "tripe", "chorizo de bilbao", "longganisa",
        "mung beans", "shrimp paste", "cocoa powder",
        # New ingredients for expanded recipes
        "ground beef", "lentils", "chickpeas", "zucchini",
        "cauliflower", "Greek yogurt", "turkey", "kale",
        "parmesan", "cream", "basil", "rosemary", "thyme",
        "panko", "mozzarella", "ground pork", "green onion",
        "sesame seeds", "peanuts", "hoisin sauce", "oyster sauce",
        "kimchi", "gochujang", "wakame", "miso",
    ]

    insert_ing = f"INSERT INTO ingredients (name) VALUES ({ph}) ON CONFLICT (name) DO NOTHING"
    if not USE_PG:
        insert_ing = f"INSERT OR IGNORE INTO ingredients (name) VALUES ({ph})"
    for ing in ingredients:
        execute(insert_ing, (ing,))

    recipes = [
        # ── Core 14 ───────────────────────────────────────────────────────────
        {
            "name": "Chicken Stir Fry",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            # Actual chicken stir-fry with vegetables in wok
            "image_url": "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&q=80",
            "instructions": "1. Slice chicken into strips and season with salt and pepper.\n2. Mix soy sauce, sesame oil, and cornstarch in a bowl.\n3. Stir-fry chicken in hot oil 3-4 min until golden. Remove.\n4. Stir-fry garlic, ginger, and mixed vegetables 2-3 min.\n5. Return chicken, pour sauce, toss everything together and serve.",
            "nutrition": (420, 38, 32, 12),
            "ingredients": [("chicken","200g"),("mixed vegetables","1.5 cups"),("soy sauce","2 tbsp"),("garlic","3 cloves"),("ginger","1 tsp"),("sesame oil","1 tbsp"),("cornstarch","1 tbsp")]
        },
        {
            "name": "Egg Fried Rice",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Asian",
            # Actual egg fried rice with scrambled egg visible
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Use day-old cold rice for best texture.\n2. Scramble eggs in a hot wok with oil. Remove and set aside.\n3. Fry garlic and onion until fragrant, 1 min.\n4. Add rice, break up clumps, toss on high heat 3 min.\n5. Return eggs, add soy sauce, mix well and serve hot.",
            "nutrition": (380, 22, 55, 9),
            "ingredients": [("rice","1 cup"),("eggs","3"),("garlic","2 cloves"),("onion","1 small"),("soy sauce","1 tbsp")]
        },
        {
            "name": "Tuna Pasta",
            "cook_time": "18 min", "difficulty": "Medium", "tags": "Italian,High-Protein",
            # Spaghetti with tuna and tomato sauce
            "image_url": "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=600&q=80",
            "instructions": "1. Cook pasta in salted boiling water until al dente.\n2. Drain canned tuna, flake with a fork.\n3. Sauté garlic in olive oil until golden, 2 min.\n4. Add chopped tomato, simmer 5 min into a light sauce.\n5. Toss in pasta and tuna, season with salt and pepper, serve.",
            "nutrition": (490, 34, 58, 11),
            "ingredients": [("pasta","100g"),("tuna","150g"),("tomato","2"),("garlic","2 cloves"),("olive oil","1 tbsp")]
        },
        {
            "name": "Beef Bowl",
            "cook_time": "25 min", "difficulty": "Medium", "tags": "High-Protein",
            # Beef donburi bowl with rice, sliced beef, and onion on top
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Slice beef very thin against the grain.\n2. Marinate in soy sauce, sugar, and ginger for 10 min.\n3. Cook white rice and keep warm.\n4. Sear beef slices and onion in a hot pan 3-4 min.\n5. Ladle beef and sauce over rice, garnish with green onion.",
            "nutrition": (550, 45, 42, 18),
            "ingredients": [("beef","200g"),("rice","1 cup"),("soy sauce","2 tbsp"),("ginger","1 tsp"),("onion","1 small")]
        },
        {
            "name": "Veggie Omelette",
            "cook_time": "10 min", "difficulty": "Easy", "tags": "Vegetarian,Low-Cal,High-Protein",
            # Folded omelette with visible vegetable filling
            "image_url": "https://images.unsplash.com/photo-1510693206972-df098062cb71?w=600&q=80",
            "instructions": "1. Beat eggs with salt and pepper until uniform.\n2. Sauté diced onion and tomato in butter 2 min.\n3. Pour egg mixture over vegetables in the pan.\n4. Cook on medium heat until edges set, then fold in half.\n5. Slide onto plate, top with cheese and serve immediately.",
            "nutrition": (310, 24, 18, 14),
            "ingredients": [("eggs","3"),("tomato","1"),("onion","0.5"),("cheese","30g"),("butter","1 tsp")]
        },
        {
            "name": "Garlic Shrimp Pasta",
            "cook_time": "22 min", "difficulty": "Medium", "tags": "Italian,High-Protein",
            # Linguine with shrimp and garlic butter sauce
            "image_url": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=600&q=80",
            "instructions": "1. Cook pasta in salted boiling water until al dente, reserve ½ cup pasta water.\n2. Sauté garlic in butter and olive oil on medium heat 1 min.\n3. Add shrimp, cook 2-3 min per side until pink. Season well.\n4. Toss in drained pasta, splash pasta water to loosen sauce.\n5. Finish with lemon juice and zest, serve immediately.",
            "nutrition": (520, 32, 54, 16),
            "ingredients": [("shrimp","200g"),("pasta","100g"),("garlic","4 cloves"),("butter","2 tbsp"),("lemon","0.5"),("olive oil","1 tbsp")]
        },
        {
            "name": "Tofu Scramble",
            "cook_time": "12 min", "difficulty": "Easy", "tags": "Vegetarian,Low-Cal,High-Protein",
            # Crumbled tofu scramble with greens, resembles scrambled eggs
            "image_url": "https://images.unsplash.com/photo-1540914124281-342587941389?w=600&q=80",
            "instructions": "1. Drain tofu and press with paper towel to remove moisture.\n2. Crumble tofu into a hot pan with oil over medium-high heat.\n3. Add minced garlic and onion, sauté 3 min until fragrant.\n4. Season with soy sauce, turmeric for colour, and pepper.\n5. Add spinach, stir until wilted, 1 min. Serve with toast.",
            "nutrition": (280, 22, 18, 10),
            "ingredients": [("tofu","200g"),("garlic","2 cloves"),("onion","0.5"),("soy sauce","1 tbsp"),("spinach","1 cup")]
        },
        {
            "name": "Salmon with Garlic Rice",
            "cook_time": "25 min", "difficulty": "Medium", "tags": "High-Protein,Low-Cal",
            # Pan-seared salmon fillet plated next to garlic rice
            "image_url": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&q=80",
            "instructions": "1. Season salmon fillet with salt, pepper, and lemon zest.\n2. Pan-sear salmon skin-side down in hot oil 4 min, flip, cook 3 min more.\n3. Cook rice with fried garlic bits stirred into the water.\n4. Plate garlic rice as base, rest salmon fillet on top.\n5. Squeeze fresh lemon over salmon and serve immediately.",
            "nutrition": (460, 42, 38, 14),
            "ingredients": [("salmon","200g"),("rice","1 cup"),("garlic","3 cloves"),("butter","1 tbsp"),("lemon","0.5")]
        },
        {
            "name": "Pork Cabbage Stir Fry",
            "cook_time": "18 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            # Stir-fried pork with wilted cabbage and sauce
            "image_url": "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&q=80",
            "instructions": "1. Slice pork thin and marinate in soy sauce and ginger 10 min.\n2. Stir-fry pork on high heat in oil until browned, 4 min. Remove.\n3. Add garlic and onion to the pan, cook 1 min.\n4. Add shredded cabbage, toss until just wilted, 3 min.\n5. Return pork, season with fish sauce, toss and serve over rice.",
            "nutrition": (390, 30, 28, 13),
            "ingredients": [("pork","200g"),("cabbage","2 cups"),("garlic","3 cloves"),("ginger","1 tsp"),("soy sauce","2 tbsp"),("fish sauce","1 tbsp")]
        },
        {
            "name": "Bacon and Egg Toast",
            "cook_time": "10 min", "difficulty": "Easy", "tags": "High-Protein",
            # Classic BLT-style toast with fried egg and bacon strips
            "image_url": "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&q=80",
            "instructions": "1. Cook bacon strips in a pan on medium heat until crispy, 3-4 min per side.\n2. Remove bacon, fry eggs in the same pan using bacon fat.\n3. Toast bread slices until golden and firm.\n4. Layer crispy bacon strips on toast, then slide the fried egg on top.\n5. Season with cracked black pepper and serve immediately.",
            "nutrition": (420, 28, 30, 20),
            "ingredients": [("bacon","3 strips"),("eggs","2"),("bread","2 slices"),("butter","1 tsp"),("pepper","to taste")]
        },
        {
            "name": "Mushroom and Spinach Pasta",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Vegetarian,Italian",
            # Pasta tossed with sautéed mushrooms and wilted spinach
            "image_url": "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=600&q=80",
            "instructions": "1. Cook pasta until al dente in well-salted boiling water.\n2. Sauté minced garlic in olive oil 1 min until golden.\n3. Add sliced mushrooms, cook on high heat until golden, 5 min.\n4. Add spinach, stir until completely wilted, about 1 min.\n5. Toss with drained pasta, season generously and serve.",
            "nutrition": (410, 18, 62, 10),
            "ingredients": [("pasta","100g"),("mushroom","150g"),("spinach","1 cup"),("garlic","3 cloves"),("olive oil","2 tbsp")]
        },
        {
            "name": "Coconut Milk Chicken",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "Asian,High-Protein",
            # Chicken pieces braised in creamy coconut milk curry
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Sauté garlic, sliced ginger, and chili in oil until fragrant, 2 min.\n2. Add chicken pieces, brown all sides 5 min.\n3. Pour in coconut milk, bring to a gentle simmer.\n4. Simmer uncovered 15 min until sauce thickens slightly.\n5. Add fish sauce and lime juice, garnish with cilantro. Serve with rice.",
            "nutrition": (480, 40, 22, 24),
            "ingredients": [("chicken","200g"),("coconut milk","200ml"),("garlic","3 cloves"),("ginger","1 tsp"),("chili","1"),("fish sauce","1 tbsp"),("lime","0.5"),("cilantro","to taste")]
        },
        {
            "name": "Potato and Egg Hash",
            "cook_time": "22 min", "difficulty": "Easy", "tags": "Vegetarian,High-Protein",
            # Crispy diced potato hash with eggs cooked on top
            "image_url": "https://images.unsplash.com/photo-1506084868230-bb9d95c24759?w=600&q=80",
            "instructions": "1. Dice potatoes into 1cm cubes, parboil 8 min until just tender, drain.\n2. Pan-fry potatoes in oil on high heat until crispy and golden, 6 min.\n3. Add diced onion and bell pepper, cook 3 min.\n4. Create wells in the hash, crack eggs into each well.\n5. Cover pan, cook until egg whites are set, 3 min. Season and serve hot.",
            "nutrition": (360, 18, 48, 12),
            "ingredients": [("potato","2 medium"),("eggs","3"),("onion","1 small"),("bell pepper","0.5"),("olive oil","2 tbsp")]
        },
        {
            "name": "Spicy Tuna Rice Bowl",
            "cook_time": "12 min", "difficulty": "Easy", "tags": "High-Protein,Low-Cal",
            # Poke-style tuna rice bowl with toppings
            "image_url": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=80",
            "instructions": "1. Cook rice and let it cool slightly.\n2. Mix drained tuna with soy sauce, sesame oil, and chili flakes.\n3. Slice cucumber into thin rounds.\n4. Assemble bowl: rice as base, spicy tuna on one side, cucumber on the other.\n5. Drizzle with lime juice and a few drops of sesame oil. Serve immediately.",
            "nutrition": (380, 35, 42, 8),
            "ingredients": [("tuna","150g"),("rice","1 cup"),("cucumber","0.5"),("soy sauce","1 tbsp"),("sesame oil","1 tsp"),("chili","0.5"),("lime","0.5")]
        },

        # ── Filipino Staples (20) ─────────────────────────────────────────────
        {
            "name": "Chicken Adobo",
            "cook_time": "35 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            # Dark braised chicken adobo pieces with glossy soy-vinegar sauce
            "image_url": "https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80",
            "instructions": "1. Combine chicken, soy sauce, vinegar, garlic, bay leaf, and pepper in a pot.\n2. Marinate for 15 min, then bring to a boil uncovered.\n3. Reduce heat and simmer covered for 20 min until chicken is cooked.\n4. Uncover, fry chicken in its own fat until golden and caramelised.\n5. Reduce remaining sauce until thick, pour over chicken. Serve with rice.",
            "nutrition": (480, 42, 8, 28),
            "ingredients": [("chicken","500g"),("soy sauce","4 tbsp"),("vinegar","3 tbsp"),("garlic","6 cloves"),("bay leaf","3"),("pepper","1 tsp")]
        },
        {
            "name": "Pork Adobo",
            "cook_time": "40 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            # Pork belly adobo pieces with dark caramelised sauce
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Combine pork belly, soy sauce, vinegar, garlic, bay leaf, and sugar in a pot.\n2. Marinate for 20 min.\n3. Bring to boil, reduce heat and simmer covered 25 min until pork is tender.\n4. Uncover and reduce sauce on high heat for 5 min until thick and glossy.\n5. Serve over steamed white rice.",
            "nutrition": (560, 36, 6, 38),
            "ingredients": [("pork belly","400g"),("soy sauce","4 tbsp"),("vinegar","3 tbsp"),("garlic","5 cloves"),("bay leaf","2"),("sugar","1 tsp")]
        },
        {
            "name": "Sinangag",
            "cook_time": "10 min", "difficulty": "Easy", "tags": "Filipino,Low-Cal",
            # Filipino garlic fried rice, golden with crispy garlic bits
            "image_url": "https://images.unsplash.com/photo-1596797882870-8c33c3c86e8c?w=600&q=80",
            "instructions": "1. Heat oil in a pan or wok over medium-high heat.\n2. Fry garlic slices until golden and crispy, 2 min. Set aside half.\n3. Add day-old cold rice, breaking up any clumps with a spatula.\n4. Toss rice on high heat for 3 min until heated through.\n5. Season with fish sauce and salt. Top with crispy garlic bits and serve hot.",
            "nutrition": (320, 6, 62, 6),
            "ingredients": [("rice","2 cups cooked"),("garlic","6 cloves"),("olive oil","2 tbsp"),("fish sauce","1 tbsp"),("salt","to taste")]
        },
        {
            "name": "Tapsilog",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            # Filipino tapsilog plate: cured beef, fried egg, and garlic rice side by side
            "image_url": "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=600&q=80",
            "instructions": "1. Marinate thinly sliced beef in soy sauce, garlic, and sugar overnight or 1 hour.\n2. Pan-fry marinated beef in oil on medium-high heat, 3 min per side.\n3. In the same pan, fry eggs sunny-side up.\n4. Serve beef and fried egg alongside sinangag (garlic fried rice).\n5. Add a small cup of vinegar dipping sauce on the side.",
            "nutrition": (620, 46, 52, 22),
            "ingredients": [("beef","200g"),("eggs","2"),("rice","1 cup"),("soy sauce","3 tbsp"),("garlic","4 cloves"),("sugar","1 tbsp"),("vinegar","2 tbsp")]
        },
        {
            "name": "Chicken Tinola",
            "cook_time": "40 min", "difficulty": "Easy", "tags": "Filipino,High-Protein,Low-Cal",
            # Clear ginger broth with chicken pieces and green leafy vegetables
            "image_url": "https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&q=80",
            "instructions": "1. Sauté sliced ginger and onion in oil until fragrant, 2 min.\n2. Add chicken pieces, brown lightly 4 min.\n3. Pour in water to cover, bring to a boil.\n4. Simmer covered for 20 min until chicken is tender.\n5. Add kangkong leaves, season with fish sauce, cook 2 min. Serve hot.",
            "nutrition": (320, 38, 12, 10),
            "ingredients": [("chicken","400g"),("ginger","2 tbsp"),("onion","1"),("garlic","3 cloves"),("fish sauce","2 tbsp"),("kangkong","2 cups")]
        },
        {
            "name": "Sinigang na Baboy",
            "cook_time": "45 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Sour tamarind pork soup with vegetables in a clear reddish broth
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Boil pork ribs in water for 5 min, discard water to remove impurities.\n2. Add fresh water, bring to boil with onion and tomato.\n3. Simmer 25 min until pork is tender.\n4. Add tamarind mix, sitaw, eggplant, and kangkong.\n5. Season with fish sauce, simmer 5 min. Serve piping hot with rice.",
            "nutrition": (420, 32, 18, 22),
            "ingredients": [("pork","400g"),("tamarind","1 packet"),("eggplant","1"),("sitaw","1 cup"),("kangkong","2 cups"),("tomato","2"),("onion","1"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Ginisang Monggo",
            "cook_time": "40 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,High-Protein",
            # Thick Filipino mung bean stew with greens, sautéed base
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Sauté garlic, onion, and tomato in oil until soft, 3 min.\n2. Add mung beans and pour in 4 cups of water.\n3. Simmer on medium heat for 25 min until beans are completely soft.\n4. Add spinach or kangkong, stir until wilted, 2 min.\n5. Season with fish sauce. Serve with fried dried fish on top if desired.",
            "nutrition": (310, 20, 46, 6),
            "ingredients": [("mung beans","1 cup"),("garlic","3 cloves"),("onion","1"),("tomato","2"),("spinach","2 cups"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Tortang Talong",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            # Eggplant omelette — grilled eggplant fanned inside a beaten egg, pan-fried
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Roast eggplants directly over a gas flame, turning until fully charred and soft.\n2. Peel off the burnt skin carefully, keeping stem intact. Flatten with a fork.\n3. Beat eggs with a pinch of salt in a shallow dish.\n4. Dip flattened eggplant into the egg mixture, coat well.\n5. Pan-fry in oil until both sides are golden. Serve with rice and fresh tomato.",
            "nutrition": (280, 14, 22, 14),
            "ingredients": [("eggplant","2 large"),("eggs","3"),("garlic","2 cloves"),("tomato","1"),("salt","to taste"),("pepper","to taste")]
        },
        {
            "name": "Champorado",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Filipino,Low-Cal",
            # Filipino chocolate rice porridge, thick and dark brown with milk drizzle
            "image_url": "https://images.unsplash.com/photo-1517093728432-a0440f8d45af?w=600&q=80",
            "instructions": "1. Rinse rice and place in a pot with 4 cups of water.\n2. Bring to boil, reduce heat and stir frequently as it thickens.\n3. Add cocoa powder and sugar, stir well to dissolve, no lumps.\n4. Simmer 10 min until thick porridge consistency, stirring constantly.\n5. Ladle into bowls, drizzle evaporated milk on top. Serve warm.",
            "nutrition": (360, 8, 72, 6),
            "ingredients": [("rice","1 cup"),("cocoa powder","3 tbsp"),("sugar","2 tbsp"),("milk","0.5 cup"),("salt","pinch")]
        },
        {
            "name": "Arroz Caldo",
            "cook_time": "35 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            # Filipino ginger chicken congee topped with egg, green onion, fried garlic
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Sauté sliced ginger, garlic, and onion in oil until very fragrant, 3 min.\n2. Add chicken pieces, cook 5 min until lightly browned.\n3. Add rice and pour in 6 cups of water or broth.\n4. Simmer 20 min, stirring often, until thick and creamy congee.\n5. Season with fish sauce, top with toasted garlic, sliced green onion, and a soft-boiled egg.",
            "nutrition": (420, 32, 48, 10),
            "ingredients": [("chicken","300g"),("rice","0.5 cup"),("ginger","2 tbsp"),("garlic","4 cloves"),("onion","1"),("eggs","2"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Bistek Tagalog",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            # Seared beef slices smothered in soy-lemon sauce with caramelised onion rings
            "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80",
            "instructions": "1. Marinate thinly sliced beef in soy sauce, lemon juice, and sugar for 30 min.\n2. Pan-fry beef slices in hot oil 2 min each side until browned. Set aside.\n3. In the same pan, cook onion rings until soft and slightly caramelised.\n4. Return beef to the pan, pour in remaining marinade.\n5. Simmer 3 min until sauce thickens slightly. Serve over steamed rice.",
            "nutrition": (490, 40, 12, 28),
            "ingredients": [("beef","250g"),("soy sauce","4 tbsp"),("lemon","2"),("onion","2 large"),("sugar","1 tsp"),("garlic","3 cloves")]
        },
        {
            "name": "Pork Nilaga",
            "cook_time": "50 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            # Clear pork boiled soup with potato, cabbage, and carrot in broth
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Boil pork in water with onion and whole peppercorns.\n2. Skim off any foam or scum that rises, then simmer for 30 min until tender.\n3. Add potato and carrot chunks, cook 10 min until fork-tender.\n4. Add cabbage wedges, cook 3 min until just wilted.\n5. Season with salt and fish sauce. Serve piping hot with rice.",
            "nutrition": (440, 34, 24, 22),
            "ingredients": [("pork","400g"),("potato","2 medium"),("carrot","1"),("cabbage","2 cups"),("onion","1"),("fish sauce","2 tbsp"),("pepper","1 tsp")]
        },
        {
            "name": "Pork Menudo",
            "cook_time": "40 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Filipino pork menudo with diced pork, potato, carrot, bell pepper in red sauce
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Sauté garlic, onion, and tomato until tomato breaks down, 4 min.\n2. Add diced pork, cook 5 min until lightly browned.\n3. Add diced potato, carrot, and bell pepper, stir to coat.\n4. Pour in soy sauce and enough water to cover, simmer 20 min.\n5. Reduce until sauce is thick. Adjust seasoning and serve with rice.",
            "nutrition": (520, 36, 38, 20),
            "ingredients": [("pork","300g"),("potato","2 medium"),("carrot","1"),("tomato","2"),("bell pepper","1"),("soy sauce","3 tbsp"),("garlic","4 cloves"),("onion","1")]
        },
        {
            "name": "Chicken Afritada",
            "cook_time": "40 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Chicken pieces braised in tomato sauce with potato, carrot, and bell pepper
            "image_url": "https://images.unsplash.com/photo-1598103442097-8b74394b95c7?w=600&q=80",
            "instructions": "1. Brown chicken pieces in hot oil all over, 5 min. Remove and set aside.\n2. Sauté garlic and onion in the same pan until soft.\n3. Add chopped tomato and fish sauce, cook until tomato breaks down, 3 min.\n4. Return chicken, add potato, carrot, bell pepper and enough water to simmer.\n5. Simmer 20 min until potatoes are tender and sauce thickens. Serve with rice.",
            "nutrition": (460, 40, 32, 16),
            "ingredients": [("chicken","400g"),("potato","2 medium"),("carrot","1"),("tomato","3"),("bell pepper","1"),("garlic","4 cloves"),("onion","1"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Pancit Bihon",
            "cook_time": "25 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Filipino bihon noodle stir-fry with colourful vegetables and chicken
            "image_url": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=80",
            "instructions": "1. Soak bihon noodles in cold water for 10 min, drain and set aside.\n2. Sauté garlic and onion in oil, add sliced chicken and cook 3 min.\n3. Add sliced carrot and shredded cabbage, stir-fry 3 min.\n4. Add soaked noodles, pour in soy sauce and chicken stock to moisten.\n5. Toss on high heat until noodles absorb the liquid. Add calamansi juice and serve.",
            "nutrition": (420, 24, 58, 10),
            "ingredients": [("noodles","200g"),("chicken","150g"),("carrot","1"),("cabbage","1 cup"),("garlic","3 cloves"),("onion","1"),("soy sauce","3 tbsp")]
        },
        {
            "name": "Lomi",
            "cook_time": "25 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Thick Filipino egg noodle soup with pork and vegetables in viscous broth
            "image_url": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=80",
            "instructions": "1. Boil pork strips in broth with garlic and onion for 10 min.\n2. Add thick egg noodles, cook 5 min until tender.\n3. Add sliced cabbage and carrot, cook 2 min.\n4. Stir in cornstarch slurry to thicken the broth until glossy.\n5. Crack eggs directly into the soup, stir gently, cook 1 min and serve immediately.",
            "nutrition": (490, 28, 62, 14),
            "ingredients": [("noodles","250g"),("pork","150g"),("eggs","2"),("cabbage","1 cup"),("carrot","1"),("garlic","3 cloves"),("soy sauce","2 tbsp"),("cornstarch","2 tbsp")]
        },
        {
            "name": "Bicol Express Classic",
            "cook_time": "35 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Pork belly cooked in spicy coconut milk with chilis, rich and creamy
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Blanch whole chilis in boiling water for 2 min to reduce heat slightly. Drain.\n2. Sauté garlic, onion, and shrimp paste in oil until fragrant, 3 min.\n3. Add sliced pork belly, cook until fat begins to render, 5 min.\n4. Pour in coconut milk, bring to a simmer.\n5. Add blanched chilis, season with fish sauce. Simmer 15 min until sauce thickens. Serve with rice.",
            "nutrition": (580, 28, 12, 44),
            "ingredients": [("pork belly","300g"),("chili","8 pieces"),("coconut milk","400ml"),("garlic","4 cloves"),("onion","1"),("shrimp paste","1 tbsp"),("fish sauce","1 tbsp")]
        },
        {
            "name": "Kare-Kare",
            "cook_time": "60 min", "difficulty": "Hard", "tags": "Filipino,High-Protein",
            # Thick peanut-based yellow stew with oxtail and vegetables, served with bagoong
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Boil oxtail in water with onion and garlic until very tender, about 45 min.\n2. Remove oxtail, reserve 3 cups of broth.\n3. Sauté onion and garlic in annatto oil until fragrant.\n4. Add broth, oxtail, and peanut butter. Stir to combine, simmer 5 min.\n5. Add eggplant, sitaw, and banana blossom. Simmer 10 min. Serve with shrimp paste on the side.",
            "nutrition": (620, 42, 28, 38),
            "ingredients": [("oxtail","500g"),("peanut butter","4 tbsp"),("eggplant","1"),("sitaw","1 cup"),("banana blossom","1 cup"),("onion","1"),("garlic","4 cloves"),("annatto","1 tbsp")]
        },
        {
            "name": "Sisig",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Sizzling sisig served on a cast iron plate with egg and chili
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Boil pork belly until tender, then grill or pan-fry until skin is crispy.\n2. Chop grilled pork finely into small, irregular pieces.\n3. Heat a cast iron plate until smoking, add a bit of oil.\n4. Fry the chopped pork on the sizzling plate until crispy edges form.\n5. Add diced onion, chili, soy sauce, and lemon juice. Top with a raw egg, mix at the table. Serve sizzling.",
            "nutrition": (540, 32, 8, 40),
            "ingredients": [("pork belly","300g"),("onion","1 large"),("chili","3"),("soy sauce","2 tbsp"),("lemon","1"),("eggs","2"),("garlic","3 cloves")]
        },
        {
            "name": "Lugaw",
            "cook_time": "30 min", "difficulty": "Easy", "tags": "Filipino,Low-Cal",
            # Plain Filipino congee/rice porridge in a bowl with toppings
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Sauté sliced ginger in oil in a pot until very fragrant, 2 min.\n2. Add rinsed rice and stir to coat in the ginger oil.\n3. Pour in 8 cups of water, bring to a boil.\n4. Reduce heat and simmer 20 min, stirring often, until thick porridge forms.\n5. Ladle into bowls, top with toasted garlic bits, sliced green onion, and a soft-boiled egg.",
            "nutrition": (260, 8, 50, 4),
            "ingredients": [("rice","0.5 cup"),("ginger","2 tbsp"),("garlic","3 cloves"),("eggs","2"),("fish sauce","1 tbsp"),("onion","1")]
        },

        # ── 5 More Filipino ───────────────────────────────────────────────────
        {
            "name": "Pakbet",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            # Ilocano mixed vegetable stew with bitter melon, eggplant, and squash in shrimp paste
            "image_url": "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&q=80",
            "instructions": "1. Sauté garlic and onion in oil until fragrant, 2 min.\n2. Add tomato and shrimp paste, cook 3 min until tomato softens.\n3. Add bitter melon, eggplant, and sitaw, stir to coat.\n4. Pour in ½ cup water, cover and steam-cook 10 min.\n5. Season to taste and serve over steamed rice.",
            "nutrition": (220, 10, 30, 7),
            "ingredients": [("bitter melon","1"),("eggplant","1"),("sitaw","1 cup"),("tomato","2"),("onion","1"),("garlic","3 cloves"),("shrimp paste","1 tbsp")]
        },
        {
            "name": "Laing",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "Filipino,Vegetarian",
            # Dried taro leaves simmered in thick spicy coconut milk
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Sauté garlic, onion, and shrimp paste in oil 3 min until fragrant.\n2. Add sliced chili and ginger, cook 1 min.\n3. Pour in first extraction of coconut milk, simmer 5 min.\n4. Add dried kangkong or taro leaves, submerge well. Do not stir yet.\n5. Simmer 15 min until leaves are tender and sauce is thick. Season and serve with rice.",
            "nutrition": (380, 10, 18, 30),
            "ingredients": [("kangkong","3 cups dried"),("coconut milk","400ml"),("chili","3"),("garlic","4 cloves"),("onion","1"),("ginger","1 tbsp"),("shrimp paste","1 tbsp")]
        },
        {
            "name": "Kaldereta",
            "cook_time": "55 min", "difficulty": "Hard", "tags": "Filipino,High-Protein",
            # Rich red tomato-based beef stew with olives, peppers, and potatoes
            "image_url": "https://images.unsplash.com/photo-1598103442097-8b74394b95c7?w=600&q=80",
            "instructions": "1. Brown beef chunks in hot oil on all sides, 5 min. Set aside.\n2. Sauté garlic and onion in the same pot until soft.\n3. Add tomato and tomato paste, cook 3 min.\n4. Return beef, add potato, carrot, bell pepper, and enough water to cover.\n5. Simmer covered 35 min until beef is fork-tender. Stir in peanut butter to thicken. Serve with rice.",
            "nutrition": (580, 44, 32, 26),
            "ingredients": [("beef","400g"),("potato","2 medium"),("carrot","1"),("tomato","3"),("bell pepper","1"),("garlic","4 cloves"),("onion","1"),("peanut butter","2 tbsp")]
        },
        {
            "name": "Dinuguan",
            "cook_time": "40 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            # Dark Filipino pork blood stew, rich and savoury
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Sauté garlic and onion in oil until golden, 3 min.\n2. Add pork pieces and cook until browned on all sides, 5 min.\n3. Pour in vinegar, do not stir — let it boil for 2 min.\n4. Add chili, fish sauce, and ½ cup water. Simmer 15 min.\n5. The sauce is rich and dark. Adjust seasoning with fish sauce. Serve with rice or puto.",
            "nutrition": (520, 34, 6, 36),
            "ingredients": [("pork belly","300g"),("vinegar","4 tbsp"),("chili","2"),("garlic","4 cloves"),("onion","1"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Pinakbet Ilocano",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            # Ilocano vegetable medley with vegetables layered and cooked in fermented fish
            "image_url": "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&q=80",
            "instructions": "1. Sauté garlic and onion in oil until soft, 2 min.\n2. Add tomato and miso paste, cook 3 min until fragrant.\n3. Layer vegetables: bitter melon, sitaw, eggplant on top — do not mix.\n4. Add ½ cup water, cover tightly and steam-cook 12 min on medium heat.\n5. Season gently with fish sauce. Toss lightly and serve with plain rice.",
            "nutrition": (210, 9, 28, 7),
            "ingredients": [("bitter melon","1"),("eggplant","1"),("sitaw","1 cup"),("tomato","2"),("garlic","3 cloves"),("onion","1"),("miso paste","1 tbsp")]
        },

        # ── 5 Asian ───────────────────────────────────────────────────────────
        {
            "name": "Korean Bibimbap",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "Asian,High-Protein",
            # Bibimbap bowl with rice, colourful vegetable toppings, fried egg, and gochujang
            "image_url": "https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&q=80",
            "instructions": "1. Cook rice and season lightly with sesame oil and salt.\n2. Sauté sliced beef with soy sauce, garlic, and sesame oil until cooked, 4 min.\n3. Quickly stir-fry spinach, carrot, and mushroom separately with garlic and sesame oil.\n4. Fry an egg sunny-side up.\n5. Arrange rice in a bowl, top with beef and each vegetable in sections. Place egg in centre, add gochujang, mix before eating.",
            "nutrition": (580, 36, 62, 16),
            "ingredients": [("rice","1 cup"),("beef","150g"),("spinach","1 cup"),("carrot","1"),("mushroom","100g"),("eggs","1"),("soy sauce","2 tbsp"),("sesame oil","1 tbsp"),("gochujang","1 tbsp")]
        },
        {
            "name": "Thai Basil Chicken",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            # Stir-fried minced chicken with basil, chili, and oyster sauce over rice
            "image_url": "https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80",
            "instructions": "1. Heat oil in a wok on very high heat until smoking.\n2. Fry garlic and chili 30 seconds, add minced chicken and press flat.\n3. Cook without stirring 2 min to get a char, then break up and toss.\n4. Add oyster sauce, soy sauce, and a pinch of sugar. Toss 1 min.\n5. Remove from heat, toss in fresh basil leaves until wilted. Serve over rice with a fried egg.",
            "nutrition": (440, 40, 26, 16),
            "ingredients": [("chicken","250g"),("basil","1 cup"),("chili","3"),("garlic","4 cloves"),("oyster sauce","2 tbsp"),("soy sauce","1 tbsp"),("eggs","1")]
        },
        {
            "name": "Japanese Gyudon",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            # Japanese beef bowl with thin beef slices and onion simmered in dashi sauce over rice
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Slice onion into half-moons and simmer in soy sauce, mirin, and sugar 5 min.\n2. Add very thinly sliced beef, submerge into the onion broth.\n3. Cook on medium heat 3-4 min until beef is just cooked.\n4. Serve over a bowl of steamed rice.\n5. Top with a soft-poached or raw egg yolk and sesame seeds.",
            "nutrition": (520, 40, 48, 16),
            "ingredients": [("beef","200g"),("rice","1 cup"),("onion","1 large"),("soy sauce","3 tbsp"),("sugar","1 tbsp"),("eggs","1"),("sesame seeds","1 tsp")]
        },
        {
            "name": "Mapo Tofu",
            "cook_time": "20 min", "difficulty": "Medium", "tags": "Asian,Vegetarian,High-Protein",
            # Silken tofu cubes in spicy dark red chili bean sauce with garlic and ginger
            "image_url": "https://images.unsplash.com/photo-1540914124281-342587941389?w=600&q=80",
            "instructions": "1. Sauté garlic, ginger, and chili in oil until fragrant, 1 min.\n2. Add gochujang or chili bean paste, fry 1 min until dark and aromatic.\n3. Pour in ½ cup water or broth, bring to a simmer.\n4. Gently slide in silken tofu cubes, spoon sauce over without breaking them.\n5. Simmer 4 min, stir in sesame oil, top with sliced green onion. Serve over rice.",
            "nutrition": (280, 18, 14, 14),
            "ingredients": [("tofu","300g"),("gochujang","2 tbsp"),("garlic","3 cloves"),("ginger","1 tsp"),("soy sauce","1 tbsp"),("sesame oil","1 tsp"),("chili","2"),("green onion","2")]
        },
        {
            "name": "Pad Thai",
            "cook_time": "20 min", "difficulty": "Medium", "tags": "Asian,High-Protein",
            # Stir-fried rice noodles with shrimp, egg, bean sprouts, peanuts
            "image_url": "https://images.unsplash.com/photo-1559314809-0d155014e29e?w=600&q=80",
            "instructions": "1. Soak rice noodles in cold water 20 min until pliable. Drain.\n2. Stir-fry shrimp in oil on high heat 2 min until pink. Push to side.\n3. Scramble eggs in the same pan, break up.\n4. Add noodles, pour soy sauce, fish sauce, and sugar. Toss vigorously 2 min.\n5. Add bean sprouts, toss 30 sec. Plate and top with crushed peanuts, lime wedge, and chili flakes.",
            "nutrition": (490, 30, 54, 14),
            "ingredients": [("noodles","150g"),("shrimp","150g"),("eggs","2"),("garlic","2 cloves"),("soy sauce","2 tbsp"),("fish sauce","1 tbsp"),("sugar","1 tsp"),("lime","0.5"),("peanuts","2 tbsp")]
        },

        # ── 4 Italian ─────────────────────────────────────────────────────
        {
            "name": "Cacio e Pepe",
            "cook_time": "20 min", "difficulty": "Medium", "tags": "Italian,Vegetarian,High-Protein",
            # Twirled spaghetti coated in creamy pecorino-pepper sauce, no cream
            "image_url": "https://images.unsplash.com/photo-1612874742237-6526221588e3?w=600&q=80",
            "instructions": "1. Cook spaghetti in well-salted water. Reserve 1 cup of starchy pasta water.\n2. Coarsely grind lots of black pepper and toast in a dry pan 1 min.\n3. Grate parmesan finely. Mix with some pasta water to form a creamy paste.\n4. Drain pasta, add to pan with pepper. Remove from heat.\n5. Add cheese paste, toss vigorously adding pasta water gradually until silky and creamy. Serve immediately.",
            "nutrition": (480, 24, 68, 12),
            "ingredients": [("pasta","100g"),("parmesan","60g"),("pepper","2 tsp"),("olive oil","1 tbsp"),("salt","to taste")]
        },
        {
            "name": "Pasta Aglio e Olio",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Italian,Vegetarian,Low-Cal",
            # Simple spaghetti with golden garlic slices and chili flakes in olive oil
            "image_url": "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=600&q=80",
            "instructions": "1. Cook spaghetti until al dente, reserve ½ cup pasta water.\n2. Slice garlic thinly. Warm olive oil in a wide pan on medium heat.\n3. Add garlic and chili flakes, cook slowly until garlic is golden, 4 min. Do not burn.\n4. Add drained pasta and a splash of pasta water. Toss vigorously to emulsify.\n5. Season with salt, add chopped parsley if available. Plate and serve immediately.",
            "nutrition": (400, 12, 64, 12),
            "ingredients": [("pasta","100g"),("garlic","6 cloves"),("olive oil","4 tbsp"),("chili","1 tsp"),("salt","to taste")]
        },
        {
            "name": "Bruschetta",
            "cook_time": "10 min", "difficulty": "Easy", "tags": "Italian,Vegetarian,Low-Cal",
            # Toasted bread topped with fresh diced tomato, basil, and garlic
            "image_url": "https://images.unsplash.com/photo-1572695157366-5e585ab2b69f?w=600&q=80",
            "instructions": "1. Dice fresh tomatoes and mix with minced garlic, olive oil, salt, and pepper.\n2. Add torn basil leaves and let the mixture rest 5 min for flavours to meld.\n3. Slice bread about 1cm thick and toast under a grill or in a pan until golden.\n4. Rub toasted bread with a cut clove of garlic while still warm.\n5. Pile tomato mixture generously on toast. Drizzle with extra olive oil and serve immediately.",
            "nutrition": (260, 8, 38, 10),
            "ingredients": [("bread","4 slices"),("tomato","3"),("garlic","3 cloves"),("basil","0.5 cup"),("olive oil","3 tbsp")]
        },
        {
            "name": "Risotto Bianco",
            "cook_time": "30 min", "difficulty": "Hard", "tags": "Italian,Vegetarian,High-Protein",
            # Creamy white risotto with parmesan, buttery and glossy
            "image_url": "https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=600&q=80",
            "instructions": "1. Heat stock in a separate pot and keep on low heat.\n2. Sauté diced onion in butter and olive oil until translucent, 4 min.\n3. Add arborio rice and toast 2 min, stirring, until edges are translucent.\n4. Add hot stock one ladle at a time, stirring constantly and waiting for absorption before adding more, 20 min total.\n5. Remove from heat, stir in butter and parmesan vigorously until creamy and glossy. Serve immediately.",
            "nutrition": (520, 18, 72, 16),
            "ingredients": [("rice","150g"),("parmesan","50g"),("butter","3 tbsp"),("onion","1"),("olive oil","1 tbsp"),("garlic","2 cloves")]
        },

        # ── 4 Vegetarian ──────────────────────────────────────────────────────
        {
            "name": "Shakshuka",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Vegetarian,Low-Cal,High-Protein",
            # Eggs poached directly in a spiced tomato and pepper sauce in a skillet
            "image_url": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=600&q=80",
            "instructions": "1. Sauté garlic, diced onion, and bell pepper in olive oil until soft, 5 min.\n2. Add canned or fresh tomato, cumin, and chili. Simmer 10 min until thick.\n3. Season generously with salt and pepper.\n4. Create wells in the sauce with a spoon, crack an egg into each well.\n5. Cover pan and cook until egg whites are set but yolks are still runny, 4-5 min. Serve from the pan with bread.",
            "nutrition": (310, 20, 22, 14),
            "ingredients": [("eggs","4"),("tomato","4"),("bell pepper","1"),("garlic","3 cloves"),("onion","1"),("olive oil","2 tbsp"),("chili","1")]
        },
        {
            "name": "Red Lentil Soup",
            "cook_time": "30 min", "difficulty": "Easy", "tags": "Vegetarian,High-Protein,Low-Cal",
            # Thick orange-red lentil soup with a swirl of oil and spices on top
            "image_url": "https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&q=80",
            "instructions": "1. Sauté diced onion and garlic in olive oil until soft, 4 min.\n2. Add rinsed red lentils and stir to coat in the oil.\n3. Pour in 4 cups of water or vegetable stock, bring to a boil.\n4. Simmer 20 min until lentils completely break down into a thick soup.\n5. Season with salt, pepper, and a squeeze of lemon. Serve with crusty bread.",
            "nutrition": (320, 22, 48, 6),
            "ingredients": [("lentils","1 cup"),("onion","1"),("garlic","3 cloves"),("olive oil","2 tbsp"),("lemon","0.5"),("cumin","1 tsp")]
        },
        {
            "name": "Caprese Salad",
            "cook_time": "5 min", "difficulty": "Easy", "tags": "Vegetarian,Low-Cal,Italian",
            # Alternating slices of fresh tomato and mozzarella with basil leaves
            "image_url": "https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=600&q=80",
            "instructions": "1. Slice fresh tomatoes and mozzarella into ½cm rounds.\n2. Alternate tomato and mozzarella slices on a plate in a line.\n3. Tuck fresh basil leaves between each slice.\n4. Drizzle generously with extra virgin olive oil.\n5. Season with flaky salt and cracked black pepper. Serve immediately at room temperature.",
            "nutrition": (280, 16, 10, 20),
            "ingredients": [("tomato","3"),("mozzarella","150g"),("basil","0.5 cup"),("olive oil","3 tbsp"),("salt","to taste"),("pepper","to taste")]
        },
        {
            "name": "Veggie Buddha Bowl",
            "cook_time": "30 min", "difficulty": "Easy", "tags": "Vegetarian,High-Protein,Low-Cal",
            # Colourful bowl with grains, roasted vegetables, greens, and tahini drizzle
            "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80",
            "instructions": "1. Cook rice or grain as base, season with a pinch of salt.\n2. Roast diced bell pepper, carrot, and broccoli with olive oil at 200°C for 18 min until caramelised.\n3. Drain and rinse chickpeas, toss with olive oil, salt, and cumin.\n4. Assemble bowl: grain base, roasted vegetables, chickpeas, and fresh cucumber slices.\n5. Drizzle with a sauce of lemon juice, olive oil, and garlic. Serve immediately.",
            "nutrition": (420, 18, 60, 12),
            "ingredients": [("rice","0.5 cup"),("chickpeas","0.5 cup"),("bell pepper","1"),("carrot","1"),("broccoli","1 cup"),("cucumber","0.5"),("olive oil","2 tbsp"),("lemon","0.5")]
        },

        # ── 4 High-Protein ────────────────────────────────────────────────────
        {
            "name": "Turkey Meatballs",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "High-Protein,Italian",
            # Golden turkey meatballs in tomato sauce
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Mix ground turkey with minced garlic, egg, salt, pepper, and panko breadcrumbs.\n2. Roll into balls slightly smaller than a golf ball.\n3. Brown meatballs in oil on all sides over medium heat, 4-5 min. Do not crowd pan.\n4. Add crushed tomato and simmer meatballs in the sauce for 15 min until cooked through.\n5. Serve over pasta or with crusty bread. Top with parmesan.",
            "nutrition": (460, 44, 22, 18),
            "ingredients": [("turkey","300g"),("garlic","3 cloves"),("eggs","1"),("tomato","3"),("olive oil","2 tbsp"),("parmesan","30g")]
        },
        {
            "name": "Tuna Salad Bowl",
            "cook_time": "10 min", "difficulty": "Easy", "tags": "High-Protein,Low-Cal",
            # Fresh tuna salad with greens, cucumber, tomato in a clear bowl
            "image_url": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&q=80",
            "instructions": "1. Drain canned tuna thoroughly and flake into a bowl.\n2. Add diced cucumber, halved tomatoes, and sliced onion.\n3. Dress with olive oil, lemon juice, salt, and pepper.\n4. Toss everything gently to combine.\n5. Serve over shredded cabbage or lettuce as the base. Optional: add a boiled egg.",
            "nutrition": (290, 34, 14, 9),
            "ingredients": [("tuna","150g"),("cucumber","1"),("tomato","2"),("onion","0.5"),("olive oil","1 tbsp"),("lemon","0.5")]
        },
        {
            "name": "Greek Yogurt Parfait",
            "cook_time": "5 min", "difficulty": "Easy", "tags": "High-Protein,Low-Cal,Vegetarian",
            # Layered parfait with thick yogurt, granola, and fruit in a tall glass
            "image_url": "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&q=80",
            "instructions": "1. Spoon half the Greek yogurt into a glass or bowl as the first layer.\n2. Add a layer of granola or crushed crackers for crunch.\n3. Add fresh fruit — sliced banana, berries, or diced mango.\n4. Repeat the layers: yogurt, granola, fruit.\n5. Drizzle honey on top and serve immediately while granola is still crunchy.",
            "nutrition": (320, 22, 38, 6),
            "ingredients": [("Greek yogurt","200g"),("sugar","1 tsp"),("lemon","0.5"),("milk","2 tbsp")]
        },
        {
            "name": "Chicken Caesar Salad",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "High-Protein,Low-Cal",
            # Romaine lettuce with grilled chicken strips, croutons, and Caesar dressing
            "image_url": "https://images.unsplash.com/photo-1512852939750-1305098529bf?w=600&q=80",
            "instructions": "1. Season chicken breast with salt, pepper, and garlic. Pan-grill 5-6 min per side.\n2. Rest chicken 3 min, then slice diagonally into strips.\n3. Toast cubed bread in olive oil in the same pan until golden croutons form.\n4. Make dressing: mix lemon juice, garlic, parmesan, olive oil, and pepper.\n5. Toss cabbage or lettuce with dressing, top with chicken strips, croutons, and extra parmesan.",
            "nutrition": (420, 46, 18, 16),
            "ingredients": [("chicken","250g"),("parmesan","40g"),("garlic","2 cloves"),("lemon","1"),("olive oil","2 tbsp"),("bread","2 slices"),("cabbage","2 cups")]
        },

        # ── 4 Low-Cal ─────────────────────────────────────────────────────────
        {
            "name": "Zucchini Noodles",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Low-Cal,Vegetarian",
            # Spiralised zucchini noodles with tomato sauce and basil
            "image_url": "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=600&q=80",
            "instructions": "1. Spiralise zucchini into noodles or use a peeler to create ribbons.\n2. Sauté garlic in olive oil 1 min, add cherry tomatoes, cook until blistered 4 min.\n3. Add zucchini noodles, toss gently on high heat for just 1-2 min. Do not overcook.\n4. Season well with salt, pepper, and a squeeze of lemon juice.\n5. Plate immediately, top with fresh basil and parmesan if desired.",
            "nutrition": (180, 8, 18, 9),
            "ingredients": [("zucchini","2 large"),("tomato","2"),("garlic","3 cloves"),("olive oil","1 tbsp"),("basil","0.25 cup"),("lemon","0.5")]
        },
        {
            "name": "Cauliflower Fried Rice",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Low-Cal,Vegetarian,High-Protein",
            # Cauliflower rice stir-fried with egg and vegetables resembling fried rice
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Grate or pulse cauliflower in a blender until it resembles rice grains.\n2. Sauté garlic and onion in oil on high heat 2 min.\n3. Add mixed vegetables, stir-fry 3 min.\n4. Push everything to the side, scramble eggs in the centre.\n5. Add cauliflower rice, soy sauce, sesame oil. Toss everything on high heat 3 min. Serve hot.",
            "nutrition": (220, 16, 20, 8),
            "ingredients": [("cauliflower","1 medium"),("eggs","2"),("mixed vegetables","1 cup"),("garlic","2 cloves"),("onion","0.5"),("soy sauce","1 tbsp"),("sesame oil","1 tsp")]
        },
        {
            "name": "Miso Soup",
            "cook_time": "10 min", "difficulty": "Easy", "tags": "Low-Cal,Vegetarian,Asian",
            # Japanese miso soup with tofu cubes and seaweed in a bowl
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Bring 3 cups of water to just below boiling — do not boil miso.\n2. Dissolve miso paste in a ladle with a small amount of the hot water.\n3. Stir dissolved miso gently back into the pot.\n4. Add cubed silken tofu and sliced green onion.\n5. Ladle into bowls immediately. Serve hot alongside rice.",
            "nutrition": (120, 8, 10, 4),
            "ingredients": [("miso paste","3 tbsp"),("tofu","100g"),("green onion","2"),("salt","to taste")]
        },
        {
            "name": "Cucumber Salad",
            "cook_time": "5 min", "difficulty": "Easy", "tags": "Low-Cal,Vegetarian,Asian",
            # Thinly sliced cucumber in a sesame-soy dressing with sesame seeds on top
            "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80",
            "instructions": "1. Slice cucumber very thin using a mandoline or sharp knife.\n2. Sprinkle with salt, toss and let rest 5 min to draw out water.\n3. Squeeze out excess moisture with your hands.\n4. Dress with soy sauce, sesame oil, rice vinegar, sugar, and chili flakes.\n5. Toss well, top with toasted sesame seeds. Refrigerate 5 min and serve cold.",
            "nutrition": (90, 4, 14, 3),
            "ingredients": [("cucumber","2"),("soy sauce","1 tbsp"),("sesame oil","1 tsp"),("vinegar","1 tbsp"),("sugar","1 tsp"),("sesame seeds","1 tsp"),("chili","0.5 tsp")]
        },

        # ── 10 Visayan/Cebuano ────────────────────────────────────────────────
        {
            "name": "Lechon Paksiw",
            "cook_time": "30 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Chop leftover lechon or roasted pork into serving pieces.\n2. Sauté garlic and onion in oil until soft, 2 min.\n3. Add pork pieces, pour in lechon sauce (or liver sauce), vinegar, and water.\n4. Add bay leaves, sugar, and pepper. Bring to a boil.\n5. Simmer uncovered 20 min until sauce thickens and pork is tender. Serve with rice.",
            "nutrition": (520, 34, 18, 32, 65),
            "ingredients": [("pork belly","400g"),("vinegar","3 tbsp"),("garlic","4 cloves"),("onion","1"),("bay leaf","2"),("sugar","1 tbsp"),("soy sauce","2 tbsp")]
        },
        {
            "name": "Sinugba na Manok",
            "cook_time": "35 min", "difficulty": "Easy", "tags": "Filipino,High-Protein,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1598103442097-8b74394b95c3?w=600&q=80",
            "instructions": "1. Marinate chicken pieces in soy sauce, calamansi juice, garlic, and pepper for 30 min.\n2. Prepare charcoal grill or heat a grill pan over high heat.\n3. Grill chicken skin-side down 8 min until charred and caramelised.\n4. Flip and grill another 8 min until cooked through. Brush with marinade while grilling.\n5. Serve with sawsawan — a dip of soy sauce, calamansi, and chili. Pair with rice.",
            "nutrition": (380, 42, 6, 18, 55),
            "ingredients": [("chicken","500g"),("soy sauce","3 tbsp"),("vinegar","2 tbsp"),("garlic","4 cloves"),("lemon","1"),("pepper","1 tsp")]
        },
        {
            "name": "Balbacua",
            "cook_time": "120 min", "difficulty": "Hard", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Cut oxtail and tripe into serving pieces, blanch in boiling water 5 min. Drain.\n2. In a large pot, sauté garlic, onion, and ginger until fragrant.\n3. Add oxtail and tripe, cover with water. Bring to boil.\n4. Add annatto powder, peanut butter, and fermented black beans. Stir well.\n5. Simmer on low heat 2 hours until gelatinous and tender. Season with fish sauce.",
            "nutrition": (580, 48, 14, 36, 120),
            "ingredients": [("oxtail","400g"),("tripe","200g"),("peanut butter","3 tbsp"),("annatto","1 tsp"),("garlic","4 cloves"),("onion","1"),("ginger","1 tbsp")]
        },
        {
            "name": "Pochero",
            "cook_time": "60 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Boil pork or beef in water with onion and peppercorns until tender, 40 min.\n2. Add saba bananas and potatoes, cook until soft, 10 min.\n3. Add cabbage and green beans, cook 5 min.\n4. Stir in tomato sauce, season with fish sauce and salt.\n5. Serve in a deep bowl with broth. Pair with white rice.",
            "nutrition": (460, 36, 32, 22, 90),
            "ingredients": [("pork","400g"),("potato","2 medium"),("cabbage","2 cups"),("tomato","2"),("onion","1"),("garlic","3 cloves"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Utan Bisaya",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80",
            "instructions": "1. Sauté garlic and onion in oil until translucent, 2 min.\n2. Add diced tomato, cook until soft and saucy, 3 min.\n3. Add eggplant, sitaw, and bitter melon slices.\n4. Pour in 1 cup water or shrimp stock. Simmer 8 min until vegetables are tender.\n5. Season with fish sauce and pepper. Serve as a side dish with rice and dried fish.",
            "nutrition": (160, 8, 24, 5, 35),
            "ingredients": [("eggplant","1"),("sitaw","1 cup"),("bitter melon","0.5"),("tomato","2"),("garlic","3 cloves"),("onion","1"),("fish sauce","1 tbsp")]
        },
        {
            "name": "Ginataan",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&q=80",
            "instructions": "1. Combine coconut milk and water in a pot, bring to a gentle simmer.\n2. Add sliced saba banana and kamote (sweet potato), cook 8 min.\n3. Add bilo-bilo (rice balls made from glutinous rice flour) or tapioca pearls.\n4. Stir in sugar and a pinch of salt, simmer until thickened, 5 min.\n5. Serve warm or chilled. Top with jackfruit strips for extra sweetness.",
            "nutrition": (310, 4, 60, 8, 45),
            "ingredients": [("coconut milk","400ml"),("sugar","3 tbsp"),("salt","pinch"),("milk","0.5 cup")]
        },
        {
            "name": "Binignit",
            "cook_time": "30 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&q=80",
            "instructions": "1. Boil coconut milk with 2 cups water in a large pot.\n2. Add diced sweet potato and taro, simmer 10 min until half-cooked.\n3. Add tapioca pearls, sago, and sliced saba banana. Stir well.\n4. Sweeten with sugar, adjust to taste. Simmer 10 min stirring often.\n5. Serve warm in bowls. Texture should be thick and creamy.",
            "nutrition": (330, 3, 64, 7, 40),
            "ingredients": [("coconut milk","400ml"),("sugar","4 tbsp"),("salt","pinch"),("potato","1 medium")]
        },
        {
            "name": "Sutukil Style Fish",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "Filipino,High-Protein,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&q=80",
            "instructions": "1. Clean and portion fresh fish (tanigue or lapu-lapu) into steaks.\n2. Grill fish steaks over charcoal 5 min per side until cooked through.\n3. Separately, simmer fish head in ginger broth for kinilaw-style soup.\n4. Prepare sawsawan: soy sauce, vinegar, ginger, onion, and chili.\n5. Serve grilled fish with the dipping sauce and steamed rice.",
            "nutrition": (290, 38, 4, 12, 80),
            "ingredients": [("salmon","300g"),("ginger","1 tbsp"),("onion","1"),("vinegar","2 tbsp"),("soy sauce","2 tbsp"),("chili","1"),("lemon","1")]
        },
        {
            "name": "Ngohiong",
            "cook_time": "40 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Mix ground pork with shredded bamboo shoots, green onion, five-spice, egg, and salt.\n2. Lay out dried bean curd sheets, place 2 tbsp filling near the edge.\n3. Roll tightly like a lumpia spring roll, seal edge with egg white.\n4. Deep-fry in hot oil 5-6 min until golden and crispy all over.\n5. Serve sliced diagonally with sweet chili dipping sauce.",
            "nutrition": (380, 22, 28, 20, 60),
            "ingredients": [("ground pork","300g"),("garlic","3 cloves"),("onion","1"),("soy sauce","2 tbsp"),("eggs","1"),("cornstarch","2 tbsp")]
        },

        # ── 10 Ilocano ────────────────────────────────────────────────────────
        {
            "name": "Bagnet",
            "cook_time": "90 min", "difficulty": "Hard", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Boil pork belly whole in water with garlic, onion, salt, and pepper until tender, 45 min.\n2. Remove and dry completely with paper towels. Air-dry 30 min or overnight.\n3. Deep-fry in hot oil on medium heat 20 min, turning occasionally, until golden.\n4. Increase heat to high, fry 5 more min until skin puffs up and crisps.\n5. Drain, chop into pieces. Serve with pinakbet or with bagnet rice.",
            "nutrition": (680, 38, 4, 56, 95),
            "ingredients": [("pork belly","600g"),("garlic","5 cloves"),("onion","1"),("salt","2 tsp"),("pepper","1 tsp"),("bay leaf","2")]
        },
        {
            "name": "Dinengdeng",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80",
            "instructions": "1. Bring 3 cups water to boil. Add fish bagoong (fermented fish paste) and stir well.\n2. Add firmer vegetables first: bitter melon, sitaw, and eggplant.\n3. Simmer 5 min until vegetables are partially cooked.\n4. Add squash blossoms or kangkong, cook 2 more min.\n5. Taste and adjust with more bagoong if needed. Serve as a side with dried fish.",
            "nutrition": (140, 8, 20, 4, 30),
            "ingredients": [("bitter melon","1"),("eggplant","1"),("sitaw","1 cup"),("kangkong","2 cups"),("garlic","2 cloves"),("shrimp paste","1 tbsp"),("fish sauce","1 tbsp")]
        },
        {
            "name": "Pinapaitan",
            "cook_time": "60 min", "difficulty": "Hard", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Clean and slice beef tripe and innards into bite-sized pieces.\n2. Sauté garlic, ginger, and onion in oil until fragrant.\n3. Add meat, brown 5 min, then pour in enough water to cover.\n4. Simmer 40 min until meat is tender. Add a small amount of bile (or ampalaya juice) for the signature bitter taste.\n5. Season with fish sauce and pepper. Garnish with green onion. Serve very hot.",
            "nutrition": (340, 36, 8, 18, 110),
            "ingredients": [("beef","300g"),("tripe","200g"),("ginger","2 tbsp"),("garlic","4 cloves"),("onion","1"),("bitter melon","0.5"),("fish sauce","2 tbsp")]
        },
        {
            "name": "Igado",
            "cook_time": "35 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Slice pork tenderloin and liver into thin strips.\n2. Marinate in soy sauce, vinegar, and garlic for 15 min.\n3. Sauté onion and garlic in oil, add pork strips, cook 5 min.\n4. Add liver strips, cook 3 min — do not overcook the liver.\n5. Pour in the marinade, add diced bell pepper, simmer 5 min until sauce thickens.",
            "nutrition": (380, 34, 12, 22, 70),
            "ingredients": [("pork","250g"),("bell pepper","1"),("garlic","4 cloves"),("onion","1"),("soy sauce","3 tbsp"),("vinegar","2 tbsp"),("pepper","1 tsp")]
        },
        {
            "name": "Longganisa Ilocano",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=600&q=80",
            "instructions": "1. Mix ground pork with garlic, vinegar, salt, pepper, and brown sugar. Knead well.\n2. Stuff mixture into pork casings or form into small cylindrical logs wrapped in plastic.\n3. Rest in the fridge overnight to develop flavour.\n4. Poke sausages with a fork, add to a pan with a splash of water.\n5. Cook on medium heat until water evaporates, then fry in own fat until brown and caramelised.",
            "nutrition": (420, 28, 8, 30, 55),
            "ingredients": [("ground pork","400g"),("garlic","6 cloves"),("vinegar","2 tbsp"),("sugar","2 tbsp"),("salt","1 tsp"),("pepper","1 tsp")]
        },
        {
            "name": "Poque-Poque",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Roast eggplants directly over flame until charred all over. Peel.\n2. Mash roasted eggplant flesh roughly with a fork.\n3. Sauté garlic, onion, and tomato in oil until soft.\n4. Add mashed eggplant, stir together 3 min.\n5. Push vegetables aside, scramble 2 eggs into the pan, fold into eggplant mixture. Season and serve.",
            "nutrition": (240, 12, 20, 12, 30),
            "ingredients": [("eggplant","2 large"),("eggs","2"),("tomato","2"),("garlic","3 cloves"),("onion","1"),("fish sauce","1 tbsp")]
        },
        {
            "name": "Inabraw",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80",
            "instructions": "1. Bring 3 cups water to simmer, add sliced ginger and onion.\n2. Dissolve fish bagoong or shrimp paste in the broth.\n3. Add harder vegetables first: sitaw and eggplant. Cook 5 min.\n4. Add leafy greens last: kangkong or spinach. Cook 2 min.\n5. Adjust saltiness with more bagoong. Serve with fried or dried fish on the side.",
            "nutrition": (120, 6, 18, 3, 28),
            "ingredients": [("kangkong","2 cups"),("eggplant","1"),("sitaw","1 cup"),("ginger","1 tbsp"),("onion","1"),("shrimp paste","1 tbsp")]
        },
        {
            "name": "Sarciado",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&q=80",
            "instructions": "1. Season fish (milkfish or tilapia) with salt and fry in oil until golden, 4 min per side.\n2. Remove fish. In the same pan, sauté garlic, onion, and diced tomato until soft.\n3. Beat eggs lightly and pour over the sautéed tomato mixture.\n4. Return fish to pan on top of the egg-tomato sauce.\n5. Cover and cook 3 min until eggs are just set. Serve immediately with rice.",
            "nutrition": (310, 34, 10, 14, 60),
            "ingredients": [("salmon","300g"),("eggs","2"),("tomato","2"),("garlic","3 cloves"),("onion","1"),("salt","1 tsp"),("olive oil","2 tbsp")]
        },
        {
            "name": "Empanada Ilocano",
            "cook_time": "45 min", "difficulty": "Hard", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600&q=80",
            "instructions": "1. Mix rice flour with water and a pinch of salt to form a pliable orange dough (add annatto for colour).\n2. Sauté garlic, onion, and ground pork until cooked. Add grated papaya and sitaw. Season.\n3. Flatten a portion of dough into a round disc.\n4. Place 2 tbsp filling in the centre, crack a small egg on top.\n5. Fold and seal dough edges. Deep-fry in hot oil until golden and crispy.",
            "nutrition": (420, 18, 48, 18, 50),
            "ingredients": [("ground pork","200g"),("eggs","4"),("garlic","3 cloves"),("onion","1"),("flour","2 cups"),("annatto","1 tsp"),("sitaw","0.5 cup")]
        },

        # ── 10 Bicolano / Mindanaoan ──────────────────────────────────────────
        {
            "name": "Bicol Express",
            "cook_time": "30 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Slice pork belly into small cubes. Sauté garlic, onion, and ginger until fragrant.\n2. Add pork, cook until browned all over, 5 min.\n3. Pour in coconut milk, bring to a simmer.\n4. Add sliced chili, shrimp paste (bagoong), and diced chili labuyo.\n5. Simmer uncovered 20 min, stirring often, until sauce thickens and oil separates. Very spicy — serve with plain rice.",
            "nutrition": (520, 32, 12, 38, 60),
            "ingredients": [("pork belly","300g"),("coconut milk","400ml"),("chili","4"),("garlic","4 cloves"),("onion","1"),("ginger","1 tbsp"),("shrimp paste","1 tbsp")]
        },
        {
            "name": "Ginataang Gulay",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&q=80",
            "instructions": "1. Sauté garlic, onion, and ginger in oil until fragrant, 2 min.\n2. Add chopped sitaw, eggplant, and bitter melon. Stir-fry 3 min.\n3. Pour in coconut milk, bring to a gentle simmer.\n4. Add shrimp paste for depth of flavour, stir well.\n5. Simmer uncovered 10 min until vegetables are tender and sauce slightly thickened.",
            "nutrition": (280, 8, 22, 18, 45),
            "ingredients": [("eggplant","1"),("sitaw","1 cup"),("coconut milk","300ml"),("garlic","3 cloves"),("onion","1"),("ginger","1 tbsp"),("shrimp paste","1 tbsp")]
        },
        {
            "name": "Sinantolan",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,Vegetarian",
            "image_url": "https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&q=80",
            "instructions": "1. Grate or slice young santol (sour fruit) thinly, squeezing out juice.\n2. Sauté garlic, onion, and shrimp paste in oil until fragrant.\n3. Add grated santol, stir-fry 2 min to remove raw taste.\n4. Pour in coconut cream, add chili labuyo slices.\n5. Simmer until thick and creamy, 8 min. Season to taste. Serve with fried fish.",
            "nutrition": (260, 6, 24, 16, 40),
            "ingredients": [("coconut milk","400ml"),("garlic","3 cloves"),("onion","1"),("chili","2"),("shrimp paste","1 tbsp"),("sugar","1 tsp")]
        },
        {
            "name": "Tiyula Itum",
            "cook_time": "60 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Char ginger and onion directly over flame until black on the outside.\n2. Combine beef or chicken with charred ginger, onion, and turmeric in a pot. Cover with water.\n3. Bring to boil, skim foam, then simmer 40 min until meat is tender.\n4. Season with salt and fish sauce. The broth will be dark from the charred aromatics.\n5. Serve in a bowl — the dark colour is the signature of this Tausug dish.",
            "nutrition": (380, 40, 6, 20, 100),
            "ingredients": [("beef","400g"),("ginger","3 tbsp"),("onion","2"),("garlic","4 cloves"),("fish sauce","2 tbsp"),("salt","1 tsp"),("pepper","1 tsp")]
        },
        {
            "name": "Pastil",
            "cook_time": "30 min", "difficulty": "Easy", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=600&q=80",
            "instructions": "1. Shred cooked chicken or tuna flakes finely.\n2. Sauté garlic, onion, and ginger in oil. Add shredded meat and stir-fry 5 min.\n3. Season with soy sauce, salt, and pepper. Remove from heat.\n4. Place a large banana leaf square over palm, add a scoop of cooked rice in the centre.\n5. Top rice with meat mixture, fold banana leaf into a neat parcel. Serve as a portable meal.",
            "nutrition": (360, 28, 42, 10, 40),
            "ingredients": [("chicken","200g"),("rice","1 cup"),("garlic","3 cloves"),("onion","1"),("ginger","1 tbsp"),("soy sauce","2 tbsp"),("coconut milk","100ml")]
        },
        {
            "name": "Pyanggang",
            "cook_time": "45 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1598103442097-8b74394b95c3?w=600&q=80",
            "instructions": "1. Roast coconut meat until very dark, almost burnt. Blend with garlic and ginger.\n2. Coat chicken pieces with the black coconut paste, let marinate 20 min.\n3. Add coconut cream to the remaining paste in a pot, bring to simmer.\n4. Add chicken, cook covered 25 min until fully cooked through.\n5. Uncover, simmer 10 min until sauce darkens and thickens. Serve with rice.",
            "nutrition": (460, 42, 12, 26, 75),
            "ingredients": [("chicken","500g"),("coconut milk","400ml"),("garlic","5 cloves"),("ginger","2 tbsp"),("onion","1"),("chili","2"),("salt","1 tsp")]
        },
        {
            "name": "Tinutungang Manok",
            "cook_time": "40 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80",
            "instructions": "1. Toast grated coconut in a dry pan, stirring constantly until very dark and smoky.\n2. Pound or blend toasted coconut with garlic and ginger into a paste.\n3. Rub chicken pieces with the paste, season with salt.\n4. Place in a pot, add coconut cream, bring to a simmer.\n5. Cook covered 30 min until chicken is tender and sauce is smoky and thick.",
            "nutrition": (440, 40, 10, 24, 70),
            "ingredients": [("chicken","500g"),("coconut milk","400ml"),("garlic","4 cloves"),("ginger","2 tbsp"),("onion","1"),("salt","1 tsp")]
        },
        {
            "name": "Ginataang Hipon",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Filipino,High-Protein,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=600&q=80",
            "instructions": "1. Sauté garlic, onion, and ginger in oil until soft.\n2. Add shrimp, cook 2 min until just pink on all sides.\n3. Pour in coconut milk, add sliced chili and sitaw.\n4. Simmer 8 min until sauce reduces slightly and shrimp are cooked through.\n5. Season with fish sauce, stir in a small knob of butter for richness. Serve with rice.",
            "nutrition": (320, 28, 14, 18, 65),
            "ingredients": [("shrimp","300g"),("coconut milk","300ml"),("garlic","4 cloves"),("onion","1"),("ginger","1 tbsp"),("chili","2"),("fish sauce","1 tbsp")]
        },
        {
            "name": "Bulalo",
            "cook_time": "120 min", "difficulty": "Medium", "tags": "Filipino,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Place beef shank and marrow bones in a large pot, cover with cold water.\n2. Bring to a boil, skim off all foam and impurities carefully.\n3. Add onion, garlic, and peppercorns. Reduce heat and simmer 2 hours until meat is fall-off-bone tender.\n4. Add cabbage, corn, and green onion in the last 10 min.\n5. Season with fish sauce and salt. Serve in a large bowl with the bone marrow intact.",
            "nutrition": (480, 44, 14, 26, 130),
            "ingredients": [("beef","500g"),("cabbage","2 cups"),("onion","1"),("garlic","3 cloves"),("pepper","1 tsp"),("fish sauce","2 tbsp"),("salt","1 tsp")]
        },

        # ── 10 Budget Asian student meals ─────────────────────────────────────
        {
            "name": "Korean Ramyeon Upgrade",
            "cook_time": "12 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=80",
            "instructions": "1. Boil noodles according to packet, add seasoning sachet.\n2. Fry a soft-boiled egg: boil 7 min exactly, peel and halve.\n3. Pan-fry spam or leftover pork slices until caramelised.\n4. Add a handful of kimchi and sesame oil to the broth.\n5. Top noodles with egg, meat, and kimchi. Sprinkle sesame seeds and green onion.",
            "nutrition": (520, 26, 62, 18, 50),
            "ingredients": [("noodles","1 pack"),("eggs","1"),("kimchi","0.5 cup"),("pork","100g"),("gochujang","1 tbsp"),("sesame oil","1 tsp"),("green onion","2")]
        },
        {
            "name": "Tamago Kake Gohan",
            "cook_time": "5 min", "difficulty": "Easy", "tags": "Asian,High-Protein,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Cook fresh Japanese-style short-grain rice and serve in a bowl while hot.\n2. Crack a raw egg directly over the hot rice.\n3. Add soy sauce, a few drops of sesame oil, and a pinch of salt.\n4. Mix vigorously — the heat of the rice will cook the egg slightly to a creamy consistency.\n5. Top with sliced green onion and toasted sesame seeds. Eat immediately.",
            "nutrition": (380, 18, 52, 10, 30),
            "ingredients": [("rice","1 cup"),("eggs","2"),("soy sauce","1 tbsp"),("sesame oil","0.5 tsp"),("green onion","2"),("sesame seeds","1 tsp")]
        },
        {
            "name": "Vietnamese Pho Inspired",
            "cook_time": "25 min", "difficulty": "Easy", "tags": "Asian,High-Protein,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=600&q=80",
            "instructions": "1. Simmer beef broth with ginger and onion charred in a dry pan 15 min for a quick pho-style base.\n2. Cook rice noodles separately according to package, drain and divide into bowls.\n3. Slice beef paper-thin — the hot broth will cook it when poured over.\n4. Ladle broth over noodles and raw beef slices.\n5. Serve with bean sprouts, lime wedge, chili, and green onion on the side.",
            "nutrition": (380, 32, 42, 8, 70),
            "ingredients": [("beef","150g"),("noodles","150g"),("ginger","1 tbsp"),("onion","1"),("soy sauce","1 tbsp"),("lemon","1"),("green onion","3")]
        },
        {
            "name": "Nasi Goreng",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Use day-old cold rice for best fried rice texture.\n2. Fry shallot, garlic, and chili paste (sambal) in oil until dark and fragrant.\n3. Add diced chicken or shrimp, stir-fry 3 min until cooked.\n4. Add rice, pour kecap manis (sweet soy sauce) and soy sauce over. Toss on high heat 3 min.\n5. Push rice aside, fry an egg sunny-side up in the pan. Serve egg on top of rice with prawn crackers.",
            "nutrition": (500, 28, 60, 16, 55),
            "ingredients": [("rice","2 cups"),("chicken","150g"),("eggs","2"),("garlic","3 cloves"),("onion","1"),("soy sauce","2 tbsp"),("chili","1"),("sesame oil","1 tsp")]
        },
        {
            "name": "Chinese Congee",
            "cook_time": "45 min", "difficulty": "Easy", "tags": "Asian,High-Protein,Low-Cal",
            "image_url": "https://images.unsplash.com/photo-1547592180-85f173990554?w=600&q=80",
            "instructions": "1. Rinse rice, combine with 6x the amount of water or chicken stock in a pot.\n2. Bring to boil, reduce heat and simmer 30 min, stirring every 5 min.\n3. Add shredded cooked chicken or century egg pieces after 20 min.\n4. Continue cooking until rice breaks down into smooth porridge.\n5. Season with sesame oil, white pepper, and soy sauce. Top with green onion, ginger strips, and fried shallots.",
            "nutrition": (280, 18, 42, 5, 35),
            "ingredients": [("rice","0.5 cup"),("chicken","150g"),("ginger","1 tbsp"),("soy sauce","1 tbsp"),("sesame oil","1 tsp"),("green onion","3"),("salt","1 tsp")]
        },
        {
            "name": "Mee Goreng",
            "cook_time": "15 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=80",
            "instructions": "1. Boil yellow egg noodles 2 min, drain and toss with a drizzle of oil.\n2. Fry minced garlic and sliced onion in hot oil until golden.\n3. Add tofu cubes and shrimp, stir-fry 3 min.\n4. Add noodles, season with kecap manis, soy sauce, and chili sauce. Toss well on high heat.\n5. Push noodles aside, scramble eggs in, fold through. Serve with lime and fried shallots.",
            "nutrition": (480, 26, 56, 16, 50),
            "ingredients": [("noodles","150g"),("tofu","100g"),("shrimp","100g"),("eggs","2"),("garlic","3 cloves"),("onion","1"),("soy sauce","2 tbsp"),("chili","1")]
        },
        {
            "name": "Oyakodon",
            "cook_time": "20 min", "difficulty": "Easy", "tags": "Asian,High-Protein",
            "image_url": "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80",
            "instructions": "1. Slice chicken thighs into bite-size pieces. Slice onion into thin wedges.\n2. Simmer dashi, soy sauce, mirin, and sugar in a small pan until combined.\n3. Add chicken and onion, cook covered on medium heat 6 min.\n4. Beat eggs lightly, pour over chicken in a circular motion. Do not stir.\n5. Cover and cook 1 min — egg should be just set and slightly runny. Slide over hot rice.",
            "nutrition": (510, 38, 50, 16, 65),
            "ingredients": [("chicken","300g"),("eggs","3"),("onion","1"),("soy sauce","3 tbsp"),("sugar","1 tbsp"),("sesame oil","1 tsp"),("rice","1 cup")]
        },
    ]

    for r in recipes:
        if USE_PG:
            rid = execute(
                f"INSERT INTO recipes (name, cook_time, difficulty, instructions, tags, image_url) VALUES ({ph},{ph},{ph},{ph},{ph},{ph}) RETURNING id",
                (r["name"], r["cook_time"], r["difficulty"], r["instructions"], r["tags"], r.get("image_url", "")),
            )
        else:
            rid = execute(
                f"INSERT INTO recipes (name, cook_time, difficulty, instructions, tags, image_url) VALUES ({ph},{ph},{ph},{ph},{ph},{ph})",
                (r["name"], r["cook_time"], r["difficulty"], r["instructions"], r["tags"], r.get("image_url", "")),
            )

        cal, pro, carb, fat = r["nutrition"][:4]
        cost = r["nutrition"][4] if len(r["nutrition"]) > 4 else 0
        execute(
            f"INSERT INTO nutrition (recipe_id, calories, protein, carbs, fat, cost_php) VALUES ({ph},{ph},{ph},{ph},{ph},{ph})",
            (rid, cal, pro, carb, fat, cost),
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
