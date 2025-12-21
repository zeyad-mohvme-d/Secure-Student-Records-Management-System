from db.connection import get_connection
from tkinter import messagebox,simpledialog

def view_profile(username):
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC ViewProfilesByRole ?", username)
        rows = cursor.fetchall()

        if not rows:
            messagebox.showinfo("Profile", "No data found")
            return

        result = ""
        for r in rows:
            result += (
                f"Name: {r.FullName}\n"
                f"Email: {r.Email}\n"
                f"Department: {r.Department}\n"
                f"Clearance: {r.ClearanceLevel}\n"
                "----------------------\n"
            )

        messagebox.showinfo("My Profile", result)

    except Exception as e:
        messagebox.showerror("Error", str(e))

def edit_own_profile(username):
    full_name = simpledialog.askstring("Edit Profile", "New Full Name:")

    if not full_name:
        return

    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "EXEC EditOwnProfile ?, ?",
            username, full_name
        )
        conn.commit()

        messagebox.showinfo("Success", "Profile updated successfully")

    except Exception as e:
        messagebox.showerror("Error", str(e))
