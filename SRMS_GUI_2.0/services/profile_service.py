from db.connection import get_connection
from tkinter import messagebox

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
