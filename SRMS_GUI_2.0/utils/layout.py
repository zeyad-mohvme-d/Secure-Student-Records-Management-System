import tkinter as tk

def create_section(parent, title):
    frame = tk.LabelFrame(
        parent,
        text=title,
        font=("Arial", 10, "bold"),
        padx=10,
        pady=10
    )
    frame.pack(fill="x", padx=15, pady=8)
    return frame