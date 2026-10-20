import sqlite3
import os
import json

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "home_inventory.db")

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # Access columns by name
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Enable foreign keys
    cursor.execute("PRAGMA foreign_keys = ON;")
    
    # 1. Create Families table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS families (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    
    # 2. Create Members table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        color TEXT DEFAULT '#4CAF50',
        pincode TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(family_id) REFERENCES families(id) ON DELETE CASCADE
    );
    """)
    
    # 3. Create Locations table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id INTEGER NOT NULL,
        parent_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        photos TEXT DEFAULT '[]', -- JSON array of strings
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(family_id) REFERENCES families(id) ON DELETE CASCADE,
        FOREIGN KEY(parent_id) REFERENCES locations(id) ON DELETE SET NULL
    );
    """)
    
    # 4. Create Items table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id INTEGER NOT NULL,
        location_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        status TEXT DEFAULT 'checked_in', -- 'checked_in' or 'checked_out'
        checked_out_by_member_id INTEGER,
        checked_out_at TIMESTAMP,
        photos TEXT DEFAULT '[]', -- JSON array of strings
        search_vector TEXT, -- JSON array of floats
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(family_id) REFERENCES families(id) ON DELETE CASCADE,
        FOREIGN KEY(location_id) REFERENCES locations(id) ON DELETE SET NULL,
        FOREIGN KEY(checked_out_by_member_id) REFERENCES members(id) ON DELETE SET NULL
    );
    """)
    
    # 5. Create Activity Logs table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        location_id INTEGER,
        action TEXT NOT NULL, -- 'check_in' or 'check_out'
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(family_id) REFERENCES families(id) ON DELETE CASCADE,
        FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE,
        FOREIGN KEY(member_id) REFERENCES members(id) ON DELETE CASCADE,
        FOREIGN KEY(location_id) REFERENCES locations(id) ON DELETE SET NULL
    );
    """)
    
    # --- SCHEMA MIGRATIONS (Self-Healing) ---
    cursor.execute("PRAGMA table_info(members);")
    columns = [row['name'] for row in cursor.fetchall()]
    if 'email' not in columns:
        cursor.execute("ALTER TABLE members ADD COLUMN email TEXT;")
        print("[Migration] Added column 'email' to 'members' table.")
    if 'google_id' not in columns:
        cursor.execute("ALTER TABLE members ADD COLUMN google_id TEXT;")
        print("[Migration] Added column 'google_id' to 'members' table.")
    
    conn.commit()
    conn.close()
