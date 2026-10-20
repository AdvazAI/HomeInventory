import psycopg2

conn = psycopg2.connect(
    host="aws-1-ap-southeast-2.pooler.supabase.com",
    port=5432,
    user="postgres.nejipbxcitinjrzyykmi",
    password="stUrecs4ED8!",
    database="postgres"
)
cur = conn.cursor()
cur.execute("""
INSERT INTO storage.buckets (id, name, public) 
VALUES ('homeinventory', 'homeinventory', true) 
ON CONFLICT (id) DO NOTHING;
""")
conn.commit()

cur.execute("SELECT id, name, public FROM storage.buckets;")
print("Supabase Storage Buckets:", cur.fetchall())
conn.close()
