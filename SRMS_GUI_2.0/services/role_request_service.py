from db.connection import get_connection


# =========================
# STUDENT: Submit Role Request
# =========================
def submit_role_request(username, requested_role, reason):
    """
    Student submits a role upgrade request.
    Role is expected to be 'TA' only (enforced by GUI).
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "EXEC SubmitRoleUpgradeRequest ?, ?, ?",
        username,
        requested_role,
        reason
    )

    conn.commit()
    conn.close()


# =========================
# ADMIN: List Pending Requests
# =========================
def list_requests(admin_user):
    """
    Returns a list of pending role requests for Admin.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "EXEC ListPendingRoleRequests ?",
        admin_user
    )

    rows = cursor.fetchall()
    conn.close()

    requests = []
    for row in rows:
        requests.append({
            "RequestID": row.RequestID,
            "Username": row.Username,
            "CurrentRole": row.CurrentRole,
            "RequestedRole": row.RequestedRole,
            "Reason": row.Reason,
            "DateSubmitted": row.DateSubmitted,
            "Status": row.Status
        })

    return requests


# =========================
# ADMIN: Approve Request (AUTO clearance)
# =========================
def approve_request(admin_user, request_id, requested_role):
    """
    Approves a role request and automatically assigns clearance.
    """
    # Automatic clearance mapping (SECURE & FIXED)
    clearance_map = {
        "TA": 3,
        "Instructor": 3
    }

    new_clearance = clearance_map.get(requested_role)

    if new_clearance is None:
        raise Exception("Invalid role for approval")

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "EXEC ResolveRoleRequest ?, ?, ?, ?",
        admin_user,
        request_id,
        "Approve",
        new_clearance
    )

    conn.commit()
    conn.close()


# =========================
# ADMIN: Deny Request
# =========================
def deny_request(admin_user, request_id):
    """
    Denies a role request without changing user role.
    """
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "EXEC ResolveRoleRequest ?, ?, ?",
        admin_user,
        request_id,
        "Deny"
    )

    conn.commit()
    conn.close()
