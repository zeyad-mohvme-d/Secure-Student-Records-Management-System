import tkinter as tk
from tkinter import ttk, messagebox
from models.session import Session
from services.attendance_service import view_attendance, record_attendance


class TAView:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("TA Dashboard")
        self.root.geometry("600x450")

    def run(self):
        tk.Label(
            self.root,
            text=f"TA Panel - {Session.username}",
            font=("Arial", 14, "bold")
        ).pack(pady=10)

        self.attendance_tab()

        self.root.mainloop()

    def attendance_tab(self):
        form = tk.Frame(self.root)
        form.pack(pady=10)

        tk.Label(form, text="Student Email").grid(row=0, column=0)
        self.student_entry = tk.Entry(form)
        self.student_entry.grid(row=0, column=1)

        tk.Label(form, text="Course ID").grid(row=1, column=0)
        self.course_entry = tk.Entry(form)
        self.course_entry.grid(row=1, column=1)

        tk.Label(form, text="Status").grid(row=2, column=0)
        self.status_var = tk.StringVar(value="1")
        tk.Radiobutton(form, text="Present", variable=self.status_var, value="1").grid(row=2, column=1)
        tk.Radiobutton(form, text="Absent", variable=self.status_var, value="0").grid(row=2, column=2)

        tk.Button(
            form,
            text="Record Attendance",
            command=self.record_attendance
        ).grid(row=3, columnspan=3, pady=5)

        tk.Button(
            form,
            text="View Attendance",
            command=self.load_attendance
        ).grid(row=4, columnspan=3, pady=5)

        self.table = ttk.Treeview(
            self.root,
            columns=("AttendanceID", "CourseID", "Status", "Date", "By"),
            show="headings"
        )

        for col in self.table["columns"]:
            self.table.heading(col, text=col)

        self.table.pack(fill="both", expand=True, pady=10)

    def record_attendance(self):
        try:
            if not self.student_entry.get() or not self.course_entry.get():
                messagebox.showerror("Error", "Please fill all fields")
                return

            record_attendance(
                Session.username,
                self.student_entry.get(),
                int(self.course_entry.get()),
                int(self.status_var.get())
            )

            messagebox.showinfo("Success", "Attendance recorded successfully")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def load_attendance(self):
        try:
            for row in self.table.get_children():
                self.table.delete(row)

            rows = view_attendance(Session.username)

            for r in rows:
                self.table.insert(
                    "", "end",
                    values=(r.AttendanceID, r.CourseID, r.Status, r.DateRecorded, r.RecordedBy)
                )
        except Exception as e:
            messagebox.showerror("Error", str(e))
