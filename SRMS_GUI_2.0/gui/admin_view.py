import tkinter as tk
from tkinter import messagebox
from utils.layout import create_section

from services.profile_service import view_profile
from services.grade_service import enter_or_update_grade, view_grades
from services.attendance_service import view_attendance
from services.role_request_service import (
    list_requests,
    approve_request,
    deny_request
)
from services.inference_service import avg_grade_by_department


# =====================================================
# Admin Dashboard
# =====================================================
def open_admin(username):
    win = tk.Toplevel()
    win.title("Admin Dashboard")
    win.geometry("550x600")

    tk.Label(
        win,
        text=f"SRMS – Admin Panel\n{username}",
        font=("Arial", 14, "bold")
    ).pack(pady=10)

    # =========================
    # Profiles
    # =========================
    profiles = create_section(win, "Profiles")
    tk.Button(
        profiles,
        text="View All Profiles",
        command=lambda: view_profile(username)
    ).pack(fill="x", pady=4)

    # =========================
    # Grades
    # =========================
    grades = create_section(win, "Grades")
    tk.Button(
        grades,
        text="Enter / Update Grade",
        command=lambda: enter_or_update_grade(username)
    ).pack(fill="x", pady=4)

    tk.Button(
        grades,
        text="View Grades",
        command=lambda: view_grades(username)
    ).pack(fill="x", pady=4)

    # =========================
    # Attendance
    # =========================
    attendance = create_section(win, "Attendance")
    tk.Button(
        attendance,
        text="View Attendance",
        command=lambda: view_attendance(username)
    ).pack(fill="x", pady=4)

    # =========================
    # Role Requests (PART B)
    # =========================
    roles = create_section(win, "Role Requests")
    tk.Button(
        roles,
        text="Manage Role Requests",
        command=lambda: open_role_requests_window(username)
    ).pack(fill="x", pady=6)

    # =========================
    # Inference Control
    # =========================
    inference = create_section(win, "Inference Control")
    tk.Button(
        inference,
        text="Average Grade by Department",
        command=lambda: avg_grade_by_department(username)
    ).pack(fill="x", pady=6)


# =====================================================
# Role Requests Management Window
# =====================================================
def open_role_requests_window(admin_user):
    win = tk.Toplevel()
    win.title("Pending Role Requests")
    win.geometry("750x450")

    tk.Label(
        win,
        text="Pending Role Upgrade Requests",
        font=("Arial", 13, "bold")
    ).pack(pady=10)

    requests = list_requests(admin_user)

    if not requests:
        tk.Label(
            win,
            text="No pending role requests",
            font=("Arial", 11)
        ).pack(pady=20)
        return

    for req in requests:
        frame = tk.Frame(win, bd=1, relief="solid", padx=8, pady=8)
        frame.pack(fill="x", padx=10, pady=6)

        info = (
            f"User: {req['Username']}\n"
            f"Current Role: {req['CurrentRole']} → Requested: {req['RequestedRole']}\n"
            f"Reason: {req['Reason']}\n"
            f"Date: {req['DateSubmitted']}"
        )

        tk.Label(frame, text=info, justify="left").pack(side="left", expand=True)

        btn_frame = tk.Frame(frame)
        btn_frame.pack(side="right")

        tk.Button(
            btn_frame,
            text="Approve",
            width=10,
            bg="#c8f7c5",
            command=lambda r=req: approve_and_refresh(
                admin_user, r["RequestID"], r["RequestedRole"], win
            )
        ).pack(pady=3)

        tk.Button(
            btn_frame,
            text="Deny",
            width=10,
            bg="#f7c5c5",
            command=lambda r=req: deny_and_refresh(
                admin_user, r["RequestID"], win
            )
        ).pack(pady=3)


# =====================================================
# Helpers
# =====================================================
def approve_and_refresh(admin_user, request_id, requested_role, window):
    try:
        approve_request(admin_user, request_id, requested_role)
        messagebox.showinfo("Success", "Request approved successfully")
        window.destroy()
        open_role_requests_window(admin_user)
    except Exception as e:
        messagebox.showerror("Error", str(e))


def deny_and_refresh(admin_user, request_id, window):
    try:
        deny_request(admin_user, request_id)
        messagebox.showinfo("Success", "Request denied")
        window.destroy()
        open_role_requests_window(admin_user)
    except Exception as e:
        messagebox.showerror("Error", str(e))
