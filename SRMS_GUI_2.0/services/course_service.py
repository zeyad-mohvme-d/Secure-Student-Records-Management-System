from db.connection import get_connection
from tkinter import messagebox

def view_public_courses(username):
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC ViewPublicCourses ?", username)
        rows = cursor.fetchall()

        if not rows:
            messagebox.showinfo("Courses", "No public courses available")
            return

        result = ""
        for r in rows:
            result += (
                f"Course ID: {r.CourseID}\n"
                f"Course Name: {r.CourseName}\n"
                f"Info: {r.PublicInfo}\n"
                "----------------------\n"
            )

        messagebox.showinfo("Public Courses", result)

    except Exception as e:
        messagebox.showerror("Error", str(e))
