from db.connection import get_connection
from tkinter import messagebox
from tkinter import simpledialog

def view_attendance(username):
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC ViewAttendance ?", username)
        rows = cursor.fetchall()

        if not rows:
            messagebox.showinfo("Attendance", "No attendance records")
            return

        result = ""
        for r in rows:
            status = "Present" if r.Status else "Absent"
            result += (
                f"Course ID: {r.CourseID}\n"
                f"Status: {status}\n"
                f"Date: {r.DateRecorded}\n"
                "----------------------\n"
            )

        messagebox.showinfo("Attendance", result)

    except Exception as e:
        messagebox.showerror("Error", str(e))

def record_attendance(username):
    student_email = simpledialog.askstring("Attendance", "Student Email:")
    course_id = simpledialog.askinteger("Attendance", "Course ID:")
    status = simpledialog.askinteger("Attendance", "Status (1 = Present, 0 = Absent)")

    if not student_email or not course_id or status is None:
        return

    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "EXEC RecordAttendance ?, ?, ?, ?",
            username, student_email, course_id, status
        )
        conn.commit()

        messagebox.showinfo("Success", "Attendance recorded")

    except Exception as e:
        messagebox.showerror("Error", str(e))
