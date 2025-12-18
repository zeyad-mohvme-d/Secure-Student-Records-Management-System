from db.connection import get_connection

def enter_or_update_grade(username, student_id, course_id, grade_value):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "EXEC dbo.usp_EnterOrUpdateGrade ?, ?, ?, ?",
            username,
            student_id,
            course_id,
            grade_value
        )
        conn.commit()
    finally:
        conn.close()


def view_grades(username, student_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "EXEC dbo.usp_ViewGrades ?, ?",
        username,
        student_id
    )
    rows = cur.fetchall()
    conn.close()
    return rows
