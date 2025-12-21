import tkinter as tk
from tkinter import messagebox

from services.role_request_service import submit_role_request


# =====================================================
# Role Upgrade Request Window
# =====================================================
def open_role_request_form(username, role):
    """
    Opens a role request form.
    Role is fixed and cannot be modified by the user.
    
    Student  -> TA
    TA       -> Instructor
    """

    win = tk.Toplevel()
    win.title("Request Role Upgrade")
    win.geometry("400x300")

    tk.Label(
        win,
        text="Request Role Upgrade",
        font=("Arial", 13, "bold")
    ).pack(pady=10)

    # =====================
    # Requested Role (FIXED)
    # =====================
    tk.Label(win, text="Requested Role").pack()
    role_entry = tk.Entry(win)
    role_entry.insert(0, role)
    role_entry.config(state="disabled")
    role_entry.pack(pady=5)

    # =====================
    # Reason
    # =====================
    tk.Label(win, text="Reason / Justification").pack()
    reason_text = tk.Text(win, height=5, width=45)
    reason_text.pack(pady=5)

    # =====================
    # Submit
    # =====================
    def submit():
        reason = reason_text.get("1.0", "end").strip()

        if not reason:
            messagebox.showerror("Error", "Reason is required")
            return

        try:
            submit_role_request(username, role, reason)
            messagebox.showinfo(
                "Success",
                "Role upgrade request submitted successfully"
            )
            win.destroy()
        except Exception as e:
            messagebox.showerror("Error", str(e))

    tk.Button(
        win,
        text="Submit Request",
        width=20,
        command=submit
    ).pack(pady=15)
