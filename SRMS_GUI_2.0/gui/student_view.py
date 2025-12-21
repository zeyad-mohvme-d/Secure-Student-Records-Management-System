import tkinter as tk
from utils.layout import create_section
from services.attendance_service import view_attendance
from services.profile_service import view_profile
from gui.role_request_view import open_role_request_form


def open_student(username):
    win = tk.Toplevel()
    win.title("Student Dashboard")
    win.geometry("350x350")

    tk.Label(
        win,
        text=f"SRMS – Student Panel\n{username}",
        font=("Arial", 13, "bold")
    ).pack(pady=10)

    # =====================
    # My Profile
    # =====================
    profile = create_section(win, "My Profile")
    tk.Button(
        profile,
        text="View Profile",
        command=lambda: view_profile(username)
    ).pack(fill="x", padx=10, pady=5)

    # =====================
    # My Attendance
    # =====================
    attendance = create_section(win, "My Attendance")
    tk.Button(
        attendance,
        text="View Attendance",
        command=lambda: view_attendance(username)
    ).pack(fill="x", padx=10, pady=5)

    # =====================
    # Role Upgrade (PART B)
    # =====================
    role_section = create_section(win, "Role Upgrade")
    tk.Button(
        role_section,
        text="Request Role Upgrade",
        width=30,
        command=lambda: open_role_request_form(username, "TA")
    ).pack(pady=5)

