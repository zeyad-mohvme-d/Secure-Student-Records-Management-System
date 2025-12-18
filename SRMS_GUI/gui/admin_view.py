import tkinter as tk
from tkinter import messagebox
from services.user_service import create_user, update_user_role
from models.session import Session

class AdminView:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Admin Dashboard")
        self.root.geometry("400x450")

    def run(self):
        tk.Label(
            self.root,
            text=f"Admin Panel - {Session.username}",
            font=("Arial", 14, "bold")
        ).pack(pady=10)

        self.create_user_section()
        self.update_role_section()

        self.root.mainloop()

    # ---------------- CREATE USER ----------------
    def create_user_section(self):
        frame = tk.LabelFrame(self.root, text="Create User")
        frame.pack(fill="x", padx=10, pady=10)

        tk.Label(frame, text="Username").grid(row=0, column=0, sticky="w")
        self.cu_username = tk.Entry(frame)
        self.cu_username.grid(row=0, column=1)

        tk.Label(frame, text="Password").grid(row=1, column=0, sticky="w")
        self.cu_password = tk.Entry(frame, show="*")
        self.cu_password.grid(row=1, column=1)

        tk.Label(frame, text="Role").grid(row=2, column=0, sticky="w")
        self.cu_role = tk.StringVar()
        tk.OptionMenu(frame, self.cu_role,
                      "Admin", "Instructor", "TA", "Student", "Guest").grid(row=2, column=1)
        self.cu_role.set("Student")

        tk.Label(frame, text="Clearance").grid(row=3, column=0, sticky="w")
        self.cu_clearance = tk.Entry(frame)
        self.cu_clearance.grid(row=3, column=1)

        tk.Button(
            frame,
            text="Create User",
            command=self.create_user_action
        ).grid(row=4, columnspan=2, pady=5)

    def create_user_action(self):
        try:
            create_user(
                Session.username,
                self.cu_username.get(),
                self.cu_password.get(),
                self.cu_role.get(),
                int(self.cu_clearance.get())
            )
            messagebox.showinfo("Success", "User created successfully")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    # ---------------- UPDATE ROLE ----------------
    def update_role_section(self):
        frame = tk.LabelFrame(self.root, text="Update User Role")
        frame.pack(fill="x", padx=10, pady=10)

        tk.Label(frame, text="Target Username").grid(row=0, column=0, sticky="w")
        self.ur_username = tk.Entry(frame)
        self.ur_username.grid(row=0, column=1)

        tk.Label(frame, text="New Role").grid(row=1, column=0, sticky="w")
        self.ur_role = tk.StringVar()
        tk.OptionMenu(frame, self.ur_role,
                      "Admin", "Instructor", "TA", "Student", "Guest").grid(row=1, column=1)
        self.ur_role.set("Student")

        tk.Label(frame, text="New Clearance").grid(row=2, column=0, sticky="w")
        self.ur_clearance = tk.Entry(frame)
        self.ur_clearance.grid(row=2, column=1)

        tk.Button(
            frame,
            text="Update Role",
            command=self.update_role_action
        ).grid(row=3, columnspan=2, pady=5)

    def update_role_action(self):
        try:
            update_user_role(
                Session.username,
                self.ur_username.get(),
                self.ur_role.get(),
                int(self.ur_clearance.get())
            )
            messagebox.showinfo("Success", "User role updated successfully")
        except Exception as e:
            messagebox.showerror("Error", str(e))
