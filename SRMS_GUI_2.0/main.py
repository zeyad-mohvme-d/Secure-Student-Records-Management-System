import tkinter as tk
from tkinter import messagebox
import sys

from auth.login import validate_login
from gui.admin_view import open_admin
from gui.instructor_view import open_instructor
from gui.ta_view import open_ta
from gui.student_view import open_student
from gui.guest_view import open_guest

# =========================
# Create Login Window
# =========================
root = tk.Tk()
root.title("SRMS Login")
root.geometry("300x220")

tk.Label(root, text="Username").pack(pady=5)
entry_user = tk.Entry(root)
entry_user.pack()

tk.Label(root, text="Password").pack(pady=5)
entry_pass = tk.Entry(root, show="*")
entry_pass.pack()

# =========================
# LOGIN HANDLER (WRITE HERE)
# =========================
def handle_login():
    username = entry_user.get()
    password = entry_pass.get()

    result = validate_login(username, password)
    if not result:
        return

    role = result["role"]

    root.withdraw()  # HIDE login window

    if role == "Admin":
        open_admin(username)
    elif role == "Instructor":
        open_instructor(username)
    elif role == "TA":
        open_ta(username)
    elif role == "Student":
        open_student(username)
    elif role == "Guest":
        open_guest()
    else:
        messagebox.showerror("Error", "Unknown role")

# =========================
# Login Button
# =========================
tk.Button(
    root,
    text="Login",
    command=handle_login
).pack(pady=15)


# =========================
# Start GUI
# =========================
root.mainloop()
