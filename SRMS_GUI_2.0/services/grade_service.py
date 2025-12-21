from db.connection import get_connection
from tkinter import simpledialog, messagebox

def enter_or_update_grade(username):
    student_email = simpledialog.askstring("Grade", "Student Email:")
    course_id = simpledialog.askinteger("Grade", "Course ID:")
    grade_value = simpledialog.askfloat("Grade", "Grade Value:")

    if not student_email or not course_id or grade_value is None:
        return

    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "EXEC EnterOrUpdateGrade ?, ?, ?, ?",
            username, student_email, course_id, grade_value
        )
        conn.commit()

        messagebox.showinfo("Success", "Grade saved successfully")

    except Exception as e:
        messagebox.showerror("Error", str(e))


def view_grades(username):
    student_email = simpledialog.askstring("View Grades", "Student Email:")

    if not student_email:
        return

    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "EXEC ViewGrades ?, ?",
            username, student_email
        )

        rows = cursor.fetchall()
        if not rows:
            messagebox.showinfo("Grades", "No grades found")
            return

        result = ""
        for r in rows:
            result += (
                f"Course ID: {r.CourseID}\n"
                f"Grade: {r.GradeValue}\n"
                f"Entered By: {r.EnteredBy}\n"
                f"Date: {r.DateEntered}\n"
                "----------------------\n"
            )

        messagebox.showinfo("Grades", result)

    except Exception as e:
        messagebox.showerror("Error", str(e))
