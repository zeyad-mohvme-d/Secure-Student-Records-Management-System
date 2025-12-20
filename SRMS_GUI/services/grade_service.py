from db.connection import get_connection

def enter_or_update_grade(username, student_email, course_id, grade_value):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "EXEC dbo.usp_EnterOrUpdateGrade ?, ?, ?, ?",
            username,
            student_email,
            course_id,
            grade_value
        )
        conn.commit()
    finally:
        conn.close()


def view_grades(username, student_email):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "EXEC dbo.ViewGrades ?, ?",
        (username, student_email)
    )
    rows = cur.fetchall()
    conn.close()
    return rows

