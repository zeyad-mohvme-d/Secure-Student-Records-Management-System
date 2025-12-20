import tkinter as tk
from tkinter import ttk, messagebox
from models.session import Session
from services.course_service import view_public_courses


class GuestView:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Guest Dashboard")
        self.root.geometry("600x400")

    def run(self):
        tk.Label(
            self.root,
            text="Welcome Guest",
            font=("Arial", 14, "bold")
        ).pack(pady=10)

        tk.Button(
            self.root,
            text="View Public Courses",
            command=self.load_courses
        ).pack(pady=5)

        self.table = ttk.Treeview(
            self.root,
            columns=("CourseID", "CourseName", "PublicInfo"),
            show="headings"
        )

        for col in self.table["columns"]:
            self.table.heading(col, text=col)

        self.table.pack(fill="both", expand=True, pady=10)

        self.root.mainloop()

    def load_courses(self):
        try:
            for row in self.table.get_children():
                self.table.delete(row)

            rows = view_public_courses(Session.username)

            for r in rows:
                self.table.insert(
                    "", "end",
                    values=(r.CourseID, r.CourseName, r.PublicInfo)
                )
        except Exception as e:
            messagebox.showerror("Error", str(e))
