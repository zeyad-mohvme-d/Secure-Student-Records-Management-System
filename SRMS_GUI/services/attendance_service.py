from db.connection import get_connection

def view_attendance(username, student_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "EXEC dbo.usp_ViewAttendance ?, ?",
        username,
        student_id
    )
    rows = cur.fetchall()
    conn.close()
    return rows
