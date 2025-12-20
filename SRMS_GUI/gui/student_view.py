import tkinter as tk
from tkinter import ttk, messagebox

from models.session import Session
from services.profile_service import view_own_profile
from services.attendance_service import view_attendance
from services.course_service import view_public_courses
from services.role_request_service import submit_role_upgrade_request


class StudentView:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Student Dashboard")
        self.root.geometry("750x520")

    def run(self):
        tk.Label(
            self.root,
            text=f"Student Panel - {Session.username}",
            font=("Arial", 14, "bold")
        ).pack(pady=10)

        nb = ttk.Notebook(self.root)
        nb.pack(fill="both", expand=True)

        self.profile_tab(nb)
        self.attendance_tab(nb)
        self.courses_tab(nb)
        self.role_request_tab(nb)

        self.root.mainloop()

    # ---------------- PROFILE ----------------
    def profile_tab(self, notebook):
        tab = ttk.Frame(notebook)
        notebook.add(tab, text="My Profile")

        tk.Button(tab, text="Load Profile", command=self.load_profile).pack(pady=8)

        self.profile_text = tk.Text(tab, height=12)
        self.profile_text.pack(fill="both", expand=True, padx=10, pady=10)

    def load_profile(self):
        try:
            self.profile_text.delete("1.0", tk.END)
            rows = view_own_profile(Session.username)

            if not rows:
                self.profile_text.insert(tk.END, "No profile found.\n")
                return

            r = rows[0]
            # columns returned from ViewOwnProfile:
            # StudentID, FullName, Email, Phone, DOB, Department, ClearanceLevel
            self.profile_text.insert(tk.END, f"StudentID: {getattr(r, 'StudentID', '')}\n")
            self.profile_text.insert(tk.END, f"FullName: {getattr(r, 'FullName', '')}\n")
            self.profile_text.insert(tk.END, f"Email: {getattr(r, 'Email', '')}\n")
            self.profile_text.insert(tk.END, f"Phone: {getattr(r, 'Phone', '')}\n")
            self.profile_text.insert(tk.END, f"DOB: {getattr(r, 'DOB', '')}\n")
            self.profile_text.insert(tk.END, f"Department: {getattr(r, 'Department', '')}\n")
            self.profile_text.insert(tk.END, f"ClearanceLevel: {getattr(r, 'ClearanceLevel', '')}\n")

        except Exception as e:
            messagebox.showerror("Error", str(e))

    # ---------------- ATTENDANCE ----------------
    def attendance_tab(self, notebook):
        tab = ttk.Frame(notebook)
        notebook.add(tab, text="My Attendance")

        tk.Button(tab, text="Load Attendance", command=self.load_attendance).pack(pady=8)

        self.att_table = ttk.Treeview(
            tab,
            columns=("AttendanceID", "StudentID", "CourseID", "Status", "DateRecorded"),
            show="headings"
        )
        for c in self.att_table["columns"]:
            self.att_table.heading(c, text=c)
        self.att_table.pack(fill="both", expand=True, padx=10, pady=10)

    def load_attendance(self):
        try:
            for row in self.att_table.get_children():
                self.att_table.delete(row)

            rows = view_attendance(Session.username)  # IMPORTANT: username فقط

            for r in rows:
                # Student view returns: AttendanceID, StudentID, CourseID, Status, DateRecorded
                self.att_table.insert(
                    "", "end",
                    values=(
                        getattr(r, "AttendanceID", ""),
                        getattr(r, "StudentID", ""),
                        getattr(r, "CourseID", ""),
                        getattr(r, "Status", ""),
                        getattr(r, "DateRecorded", "")
                    )
                )
        except Exception as e:
            messagebox.showerror("Error", str(e))

    # ---------------- PUBLIC COURSES ----------------
    def courses_tab(self, notebook):
        tab = ttk.Frame(notebook)
        notebook.add(tab, text="Public Courses")

        tk.Button(tab, text="Load Courses", command=self.load_courses).pack(pady=8)

        self.course_table = ttk.Treeview(
            tab,
            columns=("CourseID", "CourseName", "PublicInfo"),
            show="headings"
        )
        for c in self.course_table["columns"]:
            self.course_table.heading(c, text=c)
        self.course_table.pack(fill="both", expand=True, padx=10, pady=10)

    def load_courses(self):
        try:
            for row in self.course_table.get_children():
                self.course_table.delete(row)

            rows = view_public_courses(Session.username)

            for r in rows:
                self.course_table.insert(
                    "", "end",
                    values=(
                        getattr(r, "CourseID", ""),
                        getattr(r, "CourseName", ""),
                        getattr(r, "PublicInfo", "")
                    )
                )
        except Exception as e:
            messagebox.showerror("Error", str(e))

    # ---------------- ROLE REQUEST ----------------
    def role_request_tab(self, notebook):
        tab = ttk.Frame(notebook)
        notebook.add(tab, text="Role Upgrade Request")

        form = tk.Frame(tab)
        form.pack(pady=15)

        tk.Label(form, text="Requested Role").grid(row=0, column=0, sticky="w")
        self.req_role = ttk.Combobox(form, values=["TA", "Instructor", "Admin"], state="readonly")
        self.req_role.current(0)
        self.req_role.grid(row=0, column=1, padx=10)

        tk.Label(form, text="Reason").grid(row=1, column=0, sticky="nw", pady=8)
        self.req_reason = tk.Text(form, width=45, height=6)
        self.req_reason.grid(row=1, column=1, padx=10, pady=8)

        tk.Button(
            form,
            text="Submit Request",
            command=self.submit_request
        ).grid(row=2, column=0, columnspan=2, pady=10)

    def submit_request(self):
        try:
            role = self.req_role.get().strip()
            reason = self.req_reason.get("1.0", tk.END).strip()

            if not role or not reason:
                messagebox.showerror("Error", "Please choose role and write a reason.")
                return

            submit_role_upgrade_request(Session.username, role, reason)

            messagebox.showinfo("Success", "Request submitted successfully.")
            self.req_reason.delete("1.0", tk.END)

        except Exception as e:
            messagebox.showerror("Error", str(e))
