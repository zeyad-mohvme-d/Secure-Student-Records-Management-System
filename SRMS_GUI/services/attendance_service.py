from db.connection import get_connection

def view_attendance(username):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "EXEC dbo.ViewAttendance ?",
        (username,)   # لازم tuple حتى لو عنصر واحد
    )
    rows = cur.fetchall()
    conn.close()
    return rows
