import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), 'db', 'plately.db')


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def query(sql, params=()):
    conn = get_db()
    cur = conn.execute(sql, params)
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows


def execute(sql, params=()):
    conn = get_db()
    conn.execute(sql, params)
    conn.commit()
    conn.close()


def init_db():
    """Create tables and seed default data on first run."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
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
    """)

    conn.commit()
    _seed(cur, conn)
    conn.close()
    print("[DB] Initialised plately.db")


def _seed(cur, conn):
    """Seed only if recipes table is empty."""
    cur.execute("SELECT COUNT(*) as c FROM recipes")
    if cur.fetchone()[0] > 0:
        return

    ingredients = [
        "chicken", "eggs", "rice", "garlic", "onion",
        "soy sauce", "ginger", "sesame oil", "cornstarch",
        "beef", "broccoli", "pasta", "tuna", "cheese",
        "tomato", "mixed vegetables", "shrimp", "butter",
        "olive oil", "salt", "pepper", "lemon",
    ]
    for ing in ingredients:
        cur.execute("INSERT OR IGNORE INTO ingredients (name) VALUES (?)", (ing,))

    recipes = [
        {
            "name": "Chicken Stir Fry",
            "cook_time": "20 min",
            "difficulty": "Easy",
            "tags": "Asian,High-Protein",
            "instructions": "1. Slice chicken into strips and season.\n2. Mix soy sauce, sesame oil, cornstarch.\n3. Stir-fry chicken 3-4 min. Remove.\n4. Stir-fry vegetables 2-3 min.\n5. Return chicken, add sauce, toss, serve.",
            "nutrition": (420, 38, 32, 12),
            "ingredients": [("chicken", "200g"), ("mixed vegetables", "1.5 cups"),
                            ("soy sauce", "2 tbsp"), ("garlic", "3 cloves"),
                            ("ginger", "1 tsp"), ("sesame oil", "1 tbsp"),
                            ("cornstarch", "1 tbsp")],
        },
        {
            "name": "Egg Fried Rice",
            "cook_time": "15 min",
            "difficulty": "Easy",
            "tags": "Asian",
            "instructions": "1. Cook rice. Cool.\n2. Scramble eggs in wok. Remove.\n3. Fry garlic, onion.\n4. Add rice, soy sauce, toss.\n5. Return eggs, mix well, serve.",
            "nutrition": (380, 22, 55, 9),
            "ingredients": [("rice", "1 cup"), ("eggs", "3"), ("garlic", "2 cloves"),
                            ("onion", "1 small"), ("soy sauce", "1 tbsp")],
        },
        {
            "name": "Tuna Pasta",
            "cook_time": "18 min",
            "difficulty": "Medium",
            "tags": "Italian,High-Protein",
            "instructions": "1. Cook pasta al dente.\n2. Drain tuna, flake.\n3. Sauté garlic in olive oil.\n4. Add tomato, simmer 5 min.\n5. Toss pasta and tuna, serve.",
            "nutrition": (490, 34, 58, 11),
            "ingredients": [("pasta", "100g"), ("tuna", "150g"), ("tomato", "2"),
                            ("garlic", "2 cloves"), ("olive oil", "1 tbsp")],
        },
        {
            "name": "Beef Bowl",
            "cook_time": "25 min",
            "difficulty": "Medium",
            "tags": "High-Protein",
            "instructions": "1. Slice beef thin.\n2. Marinate in soy sauce, ginger.\n3. Cook rice.\n4. Sear beef 3-4 min.\n5. Serve over rice with garnish.",
            "nutrition": (550, 45, 42, 18),
            "ingredients": [("beef", "200g"), ("rice", "1 cup"), ("soy sauce", "2 tbsp"),
                            ("ginger", "1 tsp"), ("onion", "1 small")],
        },
        {
            "name": "Veggie Omelette",
            "cook_time": "10 min",
            "difficulty": "Easy",
            "tags": "Vegetarian,Low-Cal,High-Protein",
            "instructions": "1. Beat eggs with salt and pepper.\n2. Sauté onion, tomato.\n3. Pour eggs over veggies.\n4. Fold and cook 2 min.\n5. Serve with toast.",
            "nutrition": (310, 24, 18, 14),
            "ingredients": [("eggs", "3"), ("tomato", "1"), ("onion", "0.5"),
                            ("cheese", "30g"), ("butter", "1 tsp")],
        },
        {
            "name": "Garlic Shrimp Pasta",
            "cook_time": "22 min",
            "difficulty": "Medium",
            "tags": "Italian,High-Protein",
            "instructions": "1. Cook pasta.\n2. Sauté garlic in butter and olive oil.\n3. Add shrimp, cook 3 min each side.\n4. Toss with pasta and lemon juice.\n5. Season and serve.",
            "nutrition": (520, 32, 54, 16),
            "ingredients": [("shrimp", "200g"), ("pasta", "100g"), ("garlic", "4 cloves"),
                            ("butter", "2 tbsp"), ("lemon", "0.5"), ("olive oil", "1 tbsp")],
        },
    ]

    for r in recipes:
        cur.execute(
            "INSERT INTO recipes (name, cook_time, difficulty, instructions, tags) VALUES (?,?,?,?,?)",
            (r["name"], r["cook_time"], r["difficulty"], r["instructions"], r["tags"]),
        )
        recipe_id = cur.lastrowid

        cal, pro, carb, fat = r["nutrition"]
        cur.execute(
            "INSERT INTO nutrition (recipe_id, calories, protein, carbs, fat) VALUES (?,?,?,?,?)",
            (recipe_id, cal, pro, carb, fat),
        )

        for ing_name, amount in r["ingredients"]:
            cur.execute("SELECT id FROM ingredients WHERE name = ?", (ing_name,))
            row = cur.fetchone()
            if row:
                cur.execute(
                    "INSERT OR IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, amount) VALUES (?,?,?)",
                    (recipe_id, row[0], amount),
                )

    conn.commit()
    print("[DB] Seeded default recipes and ingredients")
