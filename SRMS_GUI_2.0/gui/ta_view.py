import tkinter as tk
from utils.layout import create_section

from services.profile_service import view_profile
from services.attendance_service import record_attendance, view_attendance
from gui.role_request_view import open_role_request_form


# =====================================================
# TA Dashboard
# =====================================================
def open_ta(username):
    win = tk.Toplevel()
    win.title("TA Dashboard")
    win.geometry("400x400")

    tk.Label(
        win,
        text=f"SRMS – TA Panel\n{username}",
        font=("Arial", 13, "bold")
    ).pack(pady=10)

    # =====================
    # Profiles
    # =====================
    profiles = create_section(win, "Profiles")
    tk.Button(
        profiles,
        text="View Students",
        command=lambda: view_profile(username)
    ).pack(fill="x", pady=5)

    # =====================
    # Attendance
    # =====================
    attendance = create_section(win, "Attendance")
    tk.Button(
        attendance,
        text="Record Attendance",
        command=lambda: record_attendance(username)
    ).pack(fill="x", pady=5)

    tk.Button(
        attendance,
        text="View Attendance",
        command=lambda: view_attendance(username)
    ).pack(fill="x", pady=5)

    # =====================
    # Role Upgrade (PART B)
    # =====================
    role_section = create_section(win, "Role Upgrade")

    tk.Button(
        role_section,
        text="Request Upgrade to Instructor",
        width=30,
        command=lambda: open_role_request_form(username, "Instructor")
    ).pack(pady=5)
