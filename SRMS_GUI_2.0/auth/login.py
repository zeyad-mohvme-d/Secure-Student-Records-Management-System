from db.connection import get_connection
from tkinter import messagebox

def validate_login(username, password):
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "EXEC ValidateLogin ?, ?",
            username, password
        )

        row = cursor.fetchone()
        if not row:
            messagebox.showerror("Login Failed", "Invalid username or password")
            return None

        # SQL returns: Username, RoleName, ClearanceLevel
        return {
            "username": row.Username,
            "role": row.RoleName,
            "clearance": row.ClearanceLevel
        }

    except Exception as e:
        messagebox.showerror("Login Error", str(e))
        return None