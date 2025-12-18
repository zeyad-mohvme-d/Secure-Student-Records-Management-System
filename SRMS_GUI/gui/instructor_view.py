import tkinter as tk
from tkinter import messagebox, ttk
from models.session import Session
from services.grade_service import enter_or_update_grade, view_grades
from services.attendance_service import view_attendance

class InstructorView:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Instructor Dashboard")
        self.root.geometry("700x500")

    def run(self):
        tk.Label(
            self.root,
            text=f"Instructor Panel - {Session.username}",
            font=("Arial", 14, "bold")
        ).pack(pady=10)

        notebook = ttk.Notebook(self.root)
        notebook.pack(fill="both", expand=True)

        self.grades_tab(notebook)
        self.attendance_tab(notebook)

        self.root.mainloop()

    # ---------------- GRADES TAB ----------------
    def grades_tab(self, notebook):
        tab = ttk.Frame(notebook)
        notebook.add(tab, text="Grades")

        form = tk.Frame(tab)
        form.pack(pady=10)

        tk.Label(form, text="Student ID").grid(row=0, column=0)
        self.g_student = tk.Entry(form)
        self.g_student.grid(row=0, column=1)

        tk.Label(form, text="Course ID").grid(row=1, column=0)
        self.g_course = tk.Entry(form)
        self.g_course.grid(row=1, column=1)

        tk.Label(form, text="Grade").grid(row=2, column=0)
        self.g_grade = tk.Entry(form)
        self.g_grade.grid(row=2, column=1)

        tk.Button(
            form,
            text="Enter / Update Grade",
            command=self.enter_grade
        ).grid(row=3, columnspan=2, pady=5)

        tk.Button(
            form,
            text="View Grades",
            command=self.load_grades
        ).grid(row=4, columnspan=2, pady=5)

        self.grades_table = ttk.Treeview(
            tab,
            columns=("GradeID", "CourseID", "Grade", "Date", "By"),
            show="headings"
        )
        for col in self.grades_table["columns"]:
            self.grades_table.heading(col, text=col)
        self.grades_table.pack(fill="both", expand=True, pady=10)

    def enter_grade(self):
        try:
            enter_or_update_grade(
                Session.username,
                int(self.g_student.get()),
                int(self.g_course.get()),
                float(self.g_grade.get())
            )
            messagebox.showinfo("Success", "Grade saved successfully")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def load_grades(self):
        try:
            for row in self.grades_table.get_children():
                self.grades_table.delete(row)

            rows = view_grades(
                Session.username,
                int(self.g_student.get())
            )

            for r in rows:
                self.grades_table.insert(
                    "", "end",
                    values=(r.GradeID, r.CourseID, r.GradeValue, r.DateEntered, r.EnteredBy)
                )
        except Exception as e:
            messagebox.showerror("Error", str(e))

    # ---------------- ATTENDANCE TAB ----------------
    def attendance_tab(self, notebook):
        tab = ttk.Frame(notebook)
        notebook.add(tab, text="Attendance")

        form = tk.Frame(tab)
        form.pack(pady=10)

        tk.Label(form, text="Student ID").grid(row=0, column=0)
        self.a_student = tk.Entry(form)
        self.a_student.grid(row=0, column=1)

        tk.Button(
            form,
            text="View Attendance",
            command=self.load_attendance
        ).grid(row=1, columnspan=2, pady=5)

        self.att_table = ttk.Treeview(
            tab,
            columns=("AttendanceID", "CourseID", "Status", "Date", "By"),
            show="headings"
        )
        for col in self.att_table["columns"]:
            self.att_table.heading(col, text=col)
        self.att_table.pack(fill="both", expand=True, pady=10)

    def load_attendance(self):
        try:
            for row in self.att_table.get_children():
                self.att_table.delete(row)

            rows = view_attendance(
                Session.username,
                int(self.a_student.get())
            )

            for r in rows:
                self.att_table.insert(
                    "", "end",
                    values=(r.AttendanceID, r.CourseID, r.Status, r.DateRecorded, r.RecordedBy)
                )
        except Exception as e:
            messagebox.showerror("Error", str(e))
