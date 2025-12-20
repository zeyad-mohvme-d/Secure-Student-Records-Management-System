from db.connection import get_connection

def view_public_courses(username):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "EXEC dbo.ViewPublicCourses ?",
        (username,)
    )
    rows = cur.fetchall()
    conn.close()
    return rows
