import psycopg2

conn = psycopg2.connect(
    host="aws-1-ap-southeast-2.pooler.supabase.com",
    port=5432,
    user="postgres.nejipbxcitinjrzyykmi",
    password="stUrecs4ED8!",
    database="postgres"
)
cur = conn.cursor()
cur.execute("SELECT schema_name FROM information_schema.schemata;")
print("Schemas in Supabase:", [r[0] for r in cur.fetchall()])

# Check if tables with home_ or inventory exist
cur.execute("SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') ORDER BY table_schema, table_name;")
print("\nUser tables in Supabase:")
for row in cur.fetchall():
    print(f"  {row[0]}.{row[1]}")
conn.close()
