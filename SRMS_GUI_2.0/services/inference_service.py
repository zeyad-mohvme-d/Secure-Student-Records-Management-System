from db.connection import get_connection
from tkinter import simpledialog, messagebox

def avg_grade_by_department(admin_user):
    dept = simpledialog.askstring("Inference", "Department Name:")

    if not dept:
        return

    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "EXEC AvgGradeByDepartment ?, ?",
            admin_user, dept
        )

        row = cursor.fetchone()
        if not row:
            messagebox.showinfo("Result", "No data")
            return

        result = (
            f"Department: {row.Department}\n"
            f"Average Grade: {row.AvgGrade}\n"
            f"Group Size: {row.GroupSize}"
        )

        messagebox.showinfo("Inference Result", result)

    except Exception as e:
        messagebox.showerror("Inference Blocked", str(e))
