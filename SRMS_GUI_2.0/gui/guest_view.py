import tkinter as tk
from utils.layout import create_section
from services.course_service import view_public_courses

def open_guest():
    win = tk.Toplevel()
    win.title("Guest Dashboard")
    win.geometry("300x200")

    tk.Label(
        win,
        text="SRMS – Guest Access",
        font=("Arial", 13, "bold")
    ).pack(pady=15)

    courses = create_section(win, "Public Information")
    tk.Button(courses, text="View Public Courses",
              command=lambda: view_public_courses("guest1")).pack(fill="x", pady=5)
