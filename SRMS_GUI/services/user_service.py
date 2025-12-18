from db.connection import get_connection

def create_user(admin_username, username, password, role, clearance):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "EXEC dbo.usp_CreateUser ?, ?, ?, ?, ?",
            admin_username,
            username,
            password,
            role,
            clearance
        )
        conn.commit()
    finally:
        conn.close()


def update_user_role(admin_username, target_user, new_role, new_clearance):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "EXEC dbo.usp_UpdateUserRole ?, ?, ?, ?",
            admin_username,
            target_user,
            new_role,
            new_clearance
        )
        conn.commit()
    finally:
        conn.close()
