import tkinter as tk
from utils.layout import create_section

from services.profile_service import view_profile
from services.grade_service import enter_or_update_grade, view_grades
from services.attendance_service import record_attendance, view_attendance

def open_instructor(username):
    win = tk.Toplevel()
    win.title("Instructor Dashboard")
    win.geometry("450x450")

    tk.Label(
        win,
        text=f"SRMS – Instructor Panel\n{username}",
        font=("Arial", 13, "bold")
    ).pack(pady=10)

    profiles = create_section(win, "Profiles")
    tk.Button(profiles, text="View Profiles",
              command=lambda: view_profile(username)).pack(fill="x", pady=3)

    grades = create_section(win, "Grades")
    tk.Button(grades, text="Enter / Update Grade",
              command=lambda: enter_or_update_grade(username)).pack(fill="x", pady=3)
    tk.Button(grades, text="View Grades",
              command=lambda: view_grades(username)).pack(fill="x", pady=3)

    attendance = create_section(win, "Attendance")
    tk.Button(attendance, text="Record Attendance",
              command=lambda: record_attendance(username)).pack(fill="x", pady=3)
    tk.Button(attendance, text="View Attendance",
              command=lambda: view_attendance(username)).pack(fill="x", pady=3)
