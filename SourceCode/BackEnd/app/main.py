from flask import Flask, request, jsonify, g
from datetime import datetime, timedelta
import sqlite3
import json
import os

from app.config import settings
from app.database import get_db_connection, init_db
from app.search import embedding_service

app = Flask(__name__)

# Custom CORS handler
@app.after_request
def add_cors_headers(response):
    response.headers.add("Access-Control-Allow-Origin", "*")
    response.headers.add("Access-Control-Allow-Headers", "*")
    response.headers.add("Access-Control-Allow-Methods", "*")
    return response

@app.route('/<path:path>', methods=['OPTIONS'])
def handle_options(path):
    return '', 200

# Initialize Database on Startup
with app.app_context():
    init_db()


# Database Connection Lifecycle Management
def get_db():
    if 'db' not in g:
        g.db = get_db_connection()
    return g.db

@app.teardown_appcontext
def teardown_db(exception):
    db = g.pop('db', None)
    if db is not None:
        db.close()


# Helper: Clean up activity logs older than 1 month
def trigger_parasitic_cleanup(db, family_id: int):
    one_month_ago = (datetime.utcnow() - timedelta(days=30)).strftime('%Y-%m-%d %H:%M:%S')
    try:
        cursor = db.cursor()
        cursor.execute(
            "DELETE FROM activity_logs WHERE family_id = ? AND created_at < ?",
            (family_id, one_month_ago)
        )
        db.commit()
    except Exception as e:
        db.rollback()
        app.logger.error(f"[Cleanup] Failed to clean logs: {e}")


# Helper: Debounce duplicate check-in/out operations
def check_duplicate_action(db, family_id: int, item_id: int, member_id: int, action: str) -> bool:
    five_seconds_ago = (datetime.utcnow() - timedelta(seconds=5)).strftime('%Y-%m-%d %H:%M:%S')
    cursor = db.cursor()
    cursor.execute("""
        SELECT id, created_at FROM activity_logs
        WHERE family_id = ? AND item_id = ? AND member_id = ? AND action = ? AND created_at >= ?
        ORDER BY created_at DESC LIMIT 1
    """, (family_id, item_id, member_id, action, five_seconds_ago))
    
    last_log = cursor.fetchone()
    if last_log:
        # Update timestamp of last log
        now_str = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute(
            "UPDATE activity_logs SET created_at = ? WHERE id = ?",
            (now_str, last_log['id'])
        )
        db.commit()
        return True
    return False


# Helper: Build recursive breadcrumbs path for a location
def get_location_path(db, location_id: int) -> str:
    if not location_id:
        return "No Location"
    path_nodes = []
    curr_id = location_id
    visited = set()
    cursor = db.cursor()
    
    while curr_id and curr_id not in visited:
        visited.add(curr_id)
        cursor.execute("SELECT name, parent_id FROM locations WHERE id = ?", (curr_id,))
        loc = cursor.fetchone()
        if loc:
            path_nodes.insert(0, loc['name'])
            curr_id = loc['parent_id']
        else:
            break
            
    return " > ".join(path_nodes) if path_nodes else "Unknown"


# Helper: Compute cosine similarity in Python
def python_cosine_similarity(a, b) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot_product = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot_product / (norm_a * norm_b)


# Helper: Format DateTime
def format_iso(dt):
    return dt if dt else None


# --- INITIAL SETUP / SEED ENDPOINT ---
@app.route("/api/setup", methods=["POST"])
def initial_setup():
    db = get_db()
    cursor = db.cursor()
    
    cursor.execute("SELECT id FROM families LIMIT 1")
    existing_family = cursor.fetchone()
    if existing_family:
        return jsonify({"message": "Database already seeded", "family_id": existing_family['id']}), 200

    # 1. Create Default Family
    cursor.execute("INSERT INTO families (name) VALUES (?)", ("Smith Family",))
    family_id = cursor.lastrowid

    # 2. Create Members with emails for pilot testing
    members_data = [
        ("Dad (Edward)", "#3F51B5", "1234", "edward@example.com"),
        ("Mom (Sarah)", "#E91E63", None, "sarah@example.com"),
        ("Alice", "#9C27B0", None, "alice@example.com"),
        ("Bob", "#FF9800", None, "bob@example.com")
    ]
    for name, color, pin, email in members_data:
        cursor.execute(
            "INSERT INTO members (family_id, name, color, pincode, email) VALUES (?, ?, ?, ?, ?)",
            (family_id, name, color, pin, email)
        )

    # 3. Create Locations
    cursor.execute("INSERT INTO locations (family_id, name, description) VALUES (?, ?, ?)", (family_id, "Kitchen", "Ground floor kitchen area"))
    kitchen_id = cursor.lastrowid
    
    cursor.execute("INSERT INTO locations (family_id, name, description) VALUES (?, ?, ?)", (family_id, "Garage", "Main garage & toolshed storage"))
    garage_id = cursor.lastrowid

    cursor.execute("INSERT INTO locations (family_id, parent_id, name, description) VALUES (?, ?, ?, ?)", (family_id, kitchen_id, "Cabinet A", "Upper dry storage cabinet"))
    cabinet_id = cursor.lastrowid
    
    cursor.execute("INSERT INTO locations (family_id, parent_id, name, description) VALUES (?, ?, ?, ?)", (family_id, garage_id, "Red Toolbox", "Edward's mobile metal toolbox"))
    toolbox_id = cursor.lastrowid

    # 4. Create Items with Vectors
    items_data = [
        ("Philips Screwdriver", "Medium sized blue cross-head screwdriver", toolbox_id),
        ("Ceramic Tea Cup", "Floral patterns white porcelain teacup", cabinet_id),
        ("Heavy Duty Power Drill", "DeWalt yellow cordless impact drill", garage_id),
        ("Frying Pan", "Cast iron heavy pan for cooking", kitchen_id)
    ]
    for name, description, loc_id in items_data:
        search_text = f"{name} {description}"
        vector = embedding_service.get_embedding(search_text)
        cursor.execute(
            "INSERT INTO items (family_id, location_id, name, description, status, search_vector) VALUES (?, ?, ?, ?, 'checked_in', ?)",
            (family_id, loc_id, name, description, json.dumps(vector))
        )
        
    db.commit()
    return jsonify({"message": "Database successfully seeded with default data!", "family_id": family_id}), 201


# --- GOOGLE OAUTH LOGIN ENDPOINT ---
@app.route("/api/auth/google-login", methods=["POST"])
def google_login():
    db = get_db()
    cursor = db.cursor()
    data = request.json
    email = data.get("email", "").strip().lower()
    google_id = data.get("google_id", "")
    
    if not email:
        return jsonify({"detail": "Email is required"}), 400
        
    # Search member by email
    cursor.execute("SELECT * FROM members WHERE LOWER(email) = ?", (email,))
    m = cursor.fetchone()
    
    if not m:
        return jsonify({"detail": f"No member profile found matching email '{email}'."}), 401
        
    # Associate google_id if not already set
    if not m["google_id"] and google_id:
        cursor.execute("UPDATE members SET google_id = ? WHERE id = ?", (google_id, m["id"]))
        db.commit()
        
    return jsonify({
        "id": m["id"],
        "family_id": m["family_id"],
        "name": m["name"],
        "color": m["color"],
        "email": m["email"],
        "has_pincode": m["pincode"] is not None and m["pincode"] != "",
        "created_at": m["created_at"]
    })


# --- MEMBER ENDPOINTS ---
@app.route("/api/families/<int:family_id>/members", methods=["GET"])
def get_family_members(family_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM members WHERE family_id = ?", (family_id,))
    rows = cursor.fetchall()
    
    res = []
    for r in rows:
        res.append({
            "id": r["id"],
            "family_id": r["family_id"],
            "name": r["name"],
            "color": r["color"],
            "email": r["email"],
            "has_pincode": r["pincode"] is not None and r["pincode"] != "",
            "created_at": r["created_at"]
        })
    return jsonify(res)

@app.route("/api/families/<int:family_id>/members", methods=["POST"])
def create_member(family_id):
    db = get_db()
    cursor = db.cursor()
    data = request.json
    
    email = data.get("email", "").strip().lower() if data.get("email") else None
    
    cursor.execute(
        "INSERT INTO members (family_id, name, color, pincode, email) VALUES (?, ?, ?, ?, ?)",
        (family_id, data["name"], data.get("color", "#4CAF50"), data.get("pincode"), email)
    )
    db.commit()
    member_id = cursor.lastrowid
    
    cursor.execute("SELECT * FROM members WHERE id = ?", (member_id,))
    m = cursor.fetchone()
    return jsonify({
        "id": m["id"],
        "family_id": m["family_id"],
        "name": m["name"],
        "color": m["color"],
        "email": m["email"],
        "has_pincode": m["pincode"] is not None and m["pincode"] != "",
        "created_at": m["created_at"]
    }), 201

@app.route("/api/members/<int:member_id>/verify-pin", methods=["POST"])
def verify_member_pin(member_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT pincode FROM members WHERE id = ?", (member_id,))
    member = cursor.fetchone()
    if not member:
        return jsonify({"detail": "Member not found"}), 404
        
    data = request.json
    pin = data.get("pin", "")
    if member["pincode"] == pin:
        return jsonify({"status": "verified"})
    return jsonify({"detail": "Invalid PIN"}), 401


# --- LOCATION ENDPOINTS ---
@app.route("/api/families/<int:family_id>/locations", methods=["GET"])
def get_family_locations(family_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM locations WHERE family_id = ?", (family_id,))
    rows = cursor.fetchall()
    
    res = []
    for r in rows:
        res.append({
            "id": r["id"],
            "family_id": r["family_id"],
            "parent_id": r["parent_id"],
            "name": r["name"],
            "description": r["description"],
            "photos": json.loads(r["photos"] or "[]"),
            "created_at": r["created_at"]
        })
    return jsonify(res)

@app.route("/api/families/<int:family_id>/locations", methods=["POST"])
def create_location(family_id):
    db = get_db()
    cursor = db.cursor()
    data = request.json
    photos = data.get("photos", [])
    cursor.execute(
        "INSERT INTO locations (family_id, parent_id, name, description, photos) VALUES (?, ?, ?, ?, ?)",
        (family_id, data.get("parent_id"), data["name"], data.get("description"), json.dumps(photos))
    )
    db.commit()
    loc_id = cursor.lastrowid
    
    cursor.execute("SELECT * FROM locations WHERE id = ?", (loc_id,))
    loc = cursor.fetchone()
    return jsonify({
        "id": loc["id"],
        "family_id": loc["family_id"],
        "parent_id": loc["parent_id"],
        "name": loc["name"],
        "description": loc["description"],
        "photos": json.loads(loc["photos"] or "[]"),
        "created_at": loc["created_at"]
    }), 201

# EDIT Storage Cell (Location) Endpoint
@app.route("/api/locations/<int:loc_id>", methods=["PUT"])
def update_location(loc_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM locations WHERE id = ?", (loc_id,))
    exists = cursor.fetchone()
    if not exists:
        return jsonify({"detail": "Location not found"}), 404
        
    data = request.json
    photos = data.get("photos", [])
    cursor.execute("""
        UPDATE locations
        SET name = ?, description = ?, photos = ?
        WHERE id = ?
    """, (data["name"], data.get("description"), json.dumps(photos), loc_id))
    db.commit()
    
    cursor.execute("SELECT * FROM locations WHERE id = ?", (loc_id,))
    loc = cursor.fetchone()
    return jsonify({
        "id": loc["id"],
        "family_id": loc["family_id"],
        "parent_id": loc["parent_id"],
        "name": loc["name"],
        "description": loc["description"],
        "photos": json.loads(loc["photos"] or "[]"),
        "created_at": loc["created_at"]
    })

# DELETE Storage Cell (Location) with Deletion Constraint Checks
@app.route("/api/locations/<int:loc_id>", methods=["DELETE"])
def delete_location(loc_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM locations WHERE id = ?", (loc_id,))
    exists = cursor.fetchone()
    if not exists:
        return jsonify({"detail": "Location not found"}), 404
        
    # Constraint 1: Check if any item resides in this location
    cursor.execute("SELECT COUNT(*) as count FROM items WHERE location_id = ?", (loc_id,))
    item_count = cursor.fetchone()["count"]
    if item_count > 0:
        return jsonify({"detail": f"Cannot delete location cell. There are {item_count} item(s) stored in it. Please move them first."}), 400
        
    # Constraint 2: Check if there are any child sub-locations
    cursor.execute("SELECT COUNT(*) as count FROM locations WHERE parent_id = ?", (loc_id,))
    sub_count = cursor.fetchone()["count"]
    if sub_count > 0:
        return jsonify({"detail": f"Cannot delete location cell. There are {sub_count} nested sub-location(s) configured inside it."}), 400
        
    cursor.execute("DELETE FROM locations WHERE id = ?", (loc_id,))
    db.commit()
    return '', 204

@app.route("/api/families/<int:family_id>/locations/tree", methods=["GET"])
def get_location_tree(family_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM locations WHERE family_id = ?", (family_id,))
    all_locs = cursor.fetchall()
    
    node_map = {}
    for loc in all_locs:
        node_map[loc["id"]] = {
            "id": loc["id"],
            "name": loc["name"],
            "description": loc["description"],
            "photos": json.loads(loc["photos"] or "[]"),
            "sub_locations": []
        }
    
    roots = []
    for loc in all_locs:
        node = node_map[loc["id"]]
        p_id = loc["parent_id"]
        if p_id is None:
            roots.append(node)
        else:
            parent_node = node_map.get(p_id)
            if parent_node:
                parent_node["sub_locations"].append(node)
            else:
                roots.append(node)
                
    return jsonify(roots)


# --- ITEM ENDPOINTS ---
@app.route("/api/families/<int:family_id>/items", methods=["GET"])
def get_family_items(family_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM items WHERE family_id = ?", (family_id,))
    rows = cursor.fetchall()
    
    res = []
    for item in rows:
        res.append({
            "id": item["id"],
            "family_id": item["family_id"],
            "location_id": item["location_id"],
            "name": item["name"],
            "description": item["description"],
            "status": item["status"],
            "checked_out_by_member_id": item["checked_out_by_member_id"],
            "checked_out_at": item["checked_out_at"],
            "photos": json.loads(item["photos"] or "[]"),
            "created_at": item["created_at"]
        })
    return jsonify(res)

@app.route("/api/families/<int:family_id>/items", methods=["POST"])
def create_item(family_id):
    db = get_db()
    cursor = db.cursor()
    data = request.json
    
    search_text = f"{data['name']} {data.get('description', '')}"
    vector = embedding_service.get_embedding(search_text)
    photos = data.get("photos", [])
    
    cursor.execute("""
        INSERT INTO items (family_id, location_id, name, description, status, photos, search_vector)
        VALUES (?, ?, ?, ?, 'checked_in', ?, ?)
    """, (family_id, data.get("location_id"), data["name"], data.get("description"), json.dumps(photos), json.dumps(vector)))
    db.commit()
    item_id = cursor.lastrowid
    
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    item = cursor.fetchone()
    return jsonify({
        "id": item["id"],
        "family_id": item["family_id"],
        "location_id": item["location_id"],
        "name": item["name"],
        "description": item["description"],
        "status": item["status"],
        "checked_out_by_member_id": item["checked_out_by_member_id"],
        "checked_out_at": item["checked_out_at"],
        "photos": json.loads(item["photos"] or "[]"),
        "created_at": item["created_at"]
    }), 201

@app.route("/api/items/<int:item_id>", methods=["GET"])
def get_item(item_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    item = cursor.fetchone()
    if not item:
        return jsonify({"detail": "Item not found"}), 404
        
    return jsonify({
        "id": item["id"],
        "family_id": item["family_id"],
        "location_id": item["location_id"],
        "name": item["name"],
        "description": item["description"],
        "status": item["status"],
        "checked_out_by_member_id": item["checked_out_by_member_id"],
        "checked_out_at": item["checked_out_at"],
        "photos": json.loads(item["photos"] or "[]"),
        "created_at": item["created_at"]
    })

@app.route("/api/items/<int:item_id>", methods=["PUT"])
def update_item(item_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM items WHERE id = ?", (item_id,))
    item_exists = cursor.fetchone()
    if not item_exists:
        return jsonify({"detail": "Item not found"}), 404
    
    data = request.json
    search_text = f"{data['name']} {data.get('description', '')}"
    vector = embedding_service.get_embedding(search_text)
    photos = data.get("photos", [])
    
    cursor.execute("""
        UPDATE items
        SET name = ?, description = ?, photos = ?, location_id = ?, search_vector = ?
        WHERE id = ?
    """, (data["name"], data.get("description"), json.dumps(photos), data.get("location_id"), json.dumps(vector), item_id))
    db.commit()
    
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    item = cursor.fetchone()
    return jsonify({
        "id": item["id"],
        "family_id": item["family_id"],
        "location_id": item["location_id"],
        "name": item["name"],
        "description": item["description"],
        "status": item["status"],
        "checked_out_by_member_id": item["checked_out_by_member_id"],
        "checked_out_at": item["checked_out_at"],
        "photos": json.loads(item["photos"] or "[]"),
        "created_at": item["created_at"]
    })

@app.route("/api/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM items WHERE id = ?", (item_id,))
    item_exists = cursor.fetchone()
    if not item_exists:
        return jsonify({"detail": "Item not found"}), 404
        
    cursor.execute("DELETE FROM items WHERE id = ?", (item_id,))
    db.commit()
    return '', 204


# --- CHECK-IN / CHECK-OUT ---
@app.route("/api/items/<int:item_id>/check-out", methods=["POST"])
def check_out_item(item_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    item = cursor.fetchone()
    if not item:
        return jsonify({"detail": "Item not found"}), 404
        
    data = request.json
    member_id = data["member_id"]
    now_str = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    
    cursor.execute(
        "UPDATE items SET status = 'checked_out', checked_out_by_member_id = ?, checked_out_at = ? WHERE id = ?",
        (member_id, now_str, item_id)
    )
    
    # Debounce
    is_duplicate = check_duplicate_action(db, item["family_id"], item_id, member_id, "check_out")
    if not is_duplicate:
        cursor.execute("""
            INSERT INTO activity_logs (family_id, item_id, member_id, location_id, action, created_at)
            VALUES (?, ?, ?, ?, 'check_out', ?)
        """, (item["family_id"], item_id, member_id, item["location_id"], now_str))
        
    db.commit()
    trigger_parasitic_cleanup(db, item["family_id"])
    
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    updated_item = cursor.fetchone()
    return jsonify({
        "id": updated_item["id"],
        "family_id": updated_item["family_id"],
        "location_id": updated_item["location_id"],
        "name": updated_item["name"],
        "description": updated_item["description"],
        "status": updated_item["status"],
        "checked_out_by_member_id": updated_item["checked_out_by_member_id"],
        "checked_out_at": updated_item["checked_out_at"],
        "photos": json.loads(updated_item["photos"] or "[]"),
        "created_at": updated_item["created_at"]
    })

@app.route("/api/items/<int:item_id>/check-in", methods=["POST"])
def check_in_item(item_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    item = cursor.fetchone()
    if not item:
        return jsonify({"detail": "Item not found"}), 404
        
    data = request.json
    member_id = data["member_id"]
    location_id = data.get("location_id")
    now_str = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    
    target_location = location_id if location_id else item["location_id"]
    
    cursor.execute(
        "UPDATE items SET status = 'checked_in', checked_out_by_member_id = NULL, checked_out_at = NULL, location_id = ? WHERE id = ?",
        (target_location, item_id)
    )
    
    # Debounce
    is_duplicate = check_duplicate_action(db, item["family_id"], item_id, member_id, "check_in")
    if not is_duplicate:
        cursor.execute("""
            INSERT INTO activity_logs (family_id, item_id, member_id, location_id, action, created_at)
            VALUES (?, ?, ?, ?, 'check_in', ?)
        """, (item["family_id"], item_id, member_id, target_location, now_str))
        
    db.commit()
    trigger_parasitic_cleanup(db, item["family_id"])
    
    cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
    updated_item = cursor.fetchone()
    return jsonify({
        "id": updated_item["id"],
        "family_id": updated_item["family_id"],
        "location_id": updated_item["location_id"],
        "name": updated_item["name"],
        "description": updated_item["description"],
        "status": updated_item["status"],
        "checked_out_by_member_id": updated_item["checked_out_by_member_id"],
        "checked_out_at": updated_item["checked_out_at"],
        "photos": json.loads(updated_item["photos"] or "[]"),
        "created_at": updated_item["created_at"]
    })


# --- HISTORY LOGS ---
@app.route("/api/families/<int:family_id>/logs", methods=["GET"])
def get_activity_logs(family_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT a.id, a.family_id, a.item_id, a.member_id, a.location_id, a.action, a.created_at,
               i.name as item_name, m.name as member_name
        FROM activity_logs a
        LEFT JOIN items i ON a.item_id = i.id
        LEFT JOIN members m ON a.member_id = m.id
        WHERE a.family_id = ?
        ORDER BY a.created_at DESC
    """, (family_id,))
    rows = cursor.fetchall()
    
    res = []
    for r in rows:
        loc_name = get_location_path(db, r["location_id"])
        res.append({
            "id": r["id"],
            "family_id": r["family_id"],
            "item_id": r["item_id"],
            "item_name": r["item_name"] or "Deleted Item",
            "member_id": r["member_id"],
            "member_name": r["member_name"] or "Unknown Member",
            "location_id": r["location_id"],
            "location_name": loc_name,
            "action": r["action"],
            "created_at": r["created_at"]
        })
    return jsonify(res)


# --- FUZZY SEARCH ---
@app.route("/api/families/<int:family_id>/search", methods=["GET"])
def search_items(family_id):
    db = get_db()
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify([])
        
    query_vector = embedding_service.get_embedding(q)
    cursor = db.cursor()
    cursor.execute("SELECT * FROM items WHERE family_id = ?", (family_id,))
    items = cursor.fetchall()
    
    scored_items = []
    for item in items:
        vector_str = item["search_vector"]
        if vector_str:
            vector = json.loads(vector_str)
            similarity = python_cosine_similarity(vector, query_vector)
            scored_items.append((item, similarity))
            
    scored_items.sort(key=lambda x: x[1], reverse=True)
    scored_items = scored_items[:15]
    
    res = []
    for item, similarity in scored_items:
        path = get_location_path(db, item["location_id"])
        res.append({
            "item": {
                "id": item["id"],
                "family_id": item["family_id"],
                "location_id": item["location_id"],
                "name": item["name"],
                "description": item["description"],
                "status": item["status"],
                "checked_out_by_member_id": item["checked_out_by_member_id"],
                "checked_out_at": item["checked_out_at"],
                "photos": json.loads(item["photos"] or "[]"),
                "created_at": item["created_at"]
            },
            "score": similarity,
            "location_path": path
        })
        
    return jsonify(res)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8888, debug=False)
