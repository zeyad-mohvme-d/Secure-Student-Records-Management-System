import pyodbc

def get_connection():
    return pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        "SERVER=ME\\SQLEXPRESS;"  # <-- 8er dah 3la hasb el server 3andk
        "DATABASE=SRMS_DB;"
        "Trusted_Connection=yes;"
    )