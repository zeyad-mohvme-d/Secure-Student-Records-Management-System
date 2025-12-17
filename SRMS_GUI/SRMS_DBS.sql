/* ============================================================
   Database Security – Term Project (Phase 2)
   Secure Student Records Management System (SRMS)
   Implements:
   - Schema: STUDENT, INSTRUCTOR, COURSE, GRADES, ATTENDANCE, USERS  (PDF Sec. 3) :contentReference[oaicite:1]{index=1}
   - RBAC roles + GRANT/REVOKE/DENY + all access via stored procedures (PDF 4.1) :contentReference[oaicite:2]{index=2}
   - Inference Control: min group size=3 + restricted views (PDF 4.2) :contentReference[oaicite:3]{index=3}
   - Flow Control: prevent downflow + block lower roles (PDF 4.3) :contentReference[oaicite:4]{index=4}
   - MLS: Bell-LaPadula NRU + NWD bonus via procs (PDF 4.4) :contentReference[oaicite:5]{index=5}
   - Encryption at Rest using EncryptByKey/DecryptByKey for Grades, Phone, Passwords (PDF 4.5) :contentReference[oaicite:6]{index=6}
   - Part B: Role upgrade request workflow (PDF Part B) :contentReference[oaicite:7]{index=7}
   ============================================================ */

---------------------------------------------------------------
-- TASK 0: Create Database
---------------------------------------------------------------
IF DB_ID('SRMS_DB') IS NOT NULL
BEGIN
    ALTER DATABASE SRMS_DB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SRMS_DB;
END
GO

CREATE DATABASE SRMS_DB;
GO
USE SRMS_DB;
GO

---------------------------------------------------------------
-- TASK 1: Encryption Setup (AES)  (PDF 4.5) :contentReference[oaicite:8]{index=8}
---------------------------------------------------------------
-- Database Master Key
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SRMS_MasterKey_StrongPassword_!2025';
GO

-- Certificate
CREATE CERTIFICATE SRMS_Cert
WITH SUBJECT = 'SRMS AES Certificate';
GO

-- Symmetric Key (AES_256)
CREATE SYMMETRIC KEY SRMS_AES_Key
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE SRMS_Cert;
GO

---------------------------------------------------------------
-- TASK 2: Required Schema (PDF Sec. 3) :contentReference[oaicite:9]{index=9}
---------------------------------------------------------------

/* USERS (Authentication Table) (PDF 3.6) :contentReference[oaicite:10]{index=10}
   - Username (PK)
   - Password VARBINARY (Encrypted)
   - Role (Admin/Instructor/TA/Student/Guest)
   - Clearance Level (MLS)
**/
/* STUDENT (Confidential) (PDF 3.1) :contentReference[oaicite:11]{index=11} */
CREATE TABLE dbo.Student (
    StudentID       INT            NOT NULL PRIMARY KEY,
    StudentID_ENC VARBINARY (256) NOT NULL UNIQUE,
    FullName        NVARCHAR(100)  NOT NULL,
    Email           NVARCHAR(100)  NOT NULL,
    PhoneEnc        VARBINARY(256) NOT NULL,       -- encrypt at rest
    DOB             DATE           NOT NULL,
    Department      NVARCHAR(50)   NOT NULL,
    ClearanceLevel  INT            NOT NULL CHECK (ClearanceLevel BETWEEN 1 AND 4)
);
GO

/* INSTRUCTOR (Confidential) (PDF 3.2) :contentReference[oaicite:12]{index=12} */
CREATE TABLE dbo.Instructor (
    InstructorID    INT            NOT NULL PRIMARY KEY,
    FullName        NVARCHAR(100)  NOT NULL,
    Email           NVARCHAR(100)  NOT NULL,
    ClearanceLevel  INT            NOT NULL CHECK (ClearanceLevel BETWEEN 1 AND 4)
);
GO

/* COURSE (Unclassified) (PDF 3.3) :contentReference[oaicite:13]{index=13} */
CREATE TABLE dbo.Course (
    CourseID    INT            NOT NULL PRIMARY KEY,
    CourseName  NVARCHAR(100)  NOT NULL,
    [Description] NVARCHAR(MAX) NULL,
    PublicInfo  NVARCHAR(MAX)  NULL   -- visible to guest
);
GO

/* GRADES (Secret) (PDF 3.4) :contentReference[oaicite:14]{index=14} */
CREATE TABLE dbo.Grades (
    GradeID         INT            IDENTITY(1,1) PRIMARY KEY,
    StudentID       INT            NOT NULL,
    CourseID        INT            NOT NULL,
    GradeValueEnc   VARBINARY(256) NOT NULL,        -- encrypt at rest
    DateEntered     DATETIME       NOT NULL,
    EnteredBy       NVARCHAR(50)   NOT NULL,        -- instructor username
    CONSTRAINT FK_Grades_Student FOREIGN KEY (StudentID) REFERENCES dbo.Student(StudentID),
    CONSTRAINT FK_Grades_Course  FOREIGN KEY (CourseID)  REFERENCES dbo.Course(CourseID)
);
GO

/* ATTENDANCE (Secret) (PDF 3.5) :contentReference[oaicite:15]{index=15} */
CREATE TABLE dbo.Attendance (
    AttendanceID    INT IDENTITY(1,1) PRIMARY KEY,
    StudentID       INT NOT NULL,
    CourseID        INT NOT NULL,
    [Status]        BIT NOT NULL,
    DateRecorded    DATETIME NOT NULL,
    RecordedBy      NVARCHAR(50) NOT NULL,          -- TA/Instructor username
    CONSTRAINT FK_Att_Student FOREIGN KEY (StudentID) REFERENCES dbo.Student(StudentID),
    CONSTRAINT FK_Att_Course  FOREIGN KEY (CourseID)  REFERENCES dbo.Course(CourseID)
);
GO


CREATE TABLE dbo.[Users] (
    Username        NVARCHAR(50)   NOT NULL PRIMARY KEY,
    PasswordEnc     VARBINARY(256)  NOT NULL,      -- encrypted at rest (AES)
    RoleName        NVARCHAR(20)    NOT NULL CHECK (RoleName IN ('Admin','Instructor','TA','Student','Guest')),
    ClearanceLevel  INT             NOT NULL CHECK (ClearanceLevel BETWEEN 1 AND 4)
);
GO
---------------------------------------------------------------
-- TASK 3: RBAC Roles + DENY direct table access (PDF 4.1) :contentReference[oaicite:16]{index=16}
---------------------------------------------------------------
CREATE ROLE [Admin];
CREATE ROLE [Instructor];
CREATE ROLE [TA];
CREATE ROLE [Student];
CREATE ROLE [Guests];		/*(nt check b3deen)*/
GO

-- Deny direct table access for safety (all access must be through procedures)
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.[Users]     TO PUBLIC;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Student     TO PUBLIC;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Instructor  TO PUBLIC;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Course      TO PUBLIC;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Grades      TO PUBLIC;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Attendance  TO PUBLIC;
GO

---------------------------------------------------------------
-- TASK 4: Helper function to get role/clearance (used by every procedure)
---------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_UserRole(@Username NVARCHAR(50))
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @r NVARCHAR(20);
    SELECT @r = RoleName FROM dbo.[Users] WHERE Username = @Username;
    RETURN @r;
END
GO

CREATE OR ALTER FUNCTION dbo.fn_UserClearance(@Username NVARCHAR(50))
RETURNS INT
AS
BEGIN
    DECLARE @c INT;
    SELECT @c = ClearanceLevel FROM dbo.[Users] WHERE Username = @Username;
    RETURN @c;
END
GO

---------------------------------------------------------------
-- TASK 5: Stored procedures for ALL operations + Role verification (PDF 4.1) :contentReference[oaicite:17]{index=17}
-- MLS Classification Levels used:
-- Unclassified=1, Confidential=2, Secret=3, TopSecret=4
---------------------------------------------------------------

/* ===== Authentication (Password encrypted at rest) ===== */
CREATE OR ALTER PROCEDURE dbo.usp_CreateUser
    @AdminUser     NVARCHAR(50),
    @Username      NVARCHAR(50),
    @PlainPassword NVARCHAR(200),
    @RoleName      NVARCHAR(20),
    @Clearance     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_UserRole(@AdminUser) <> 'Admin'
        THROW 50001, 'Access denied: Admin only.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    INSERT INTO dbo.[Users](Username, PasswordEnc, RoleName, ClearanceLevel)
    VALUES (@Username,
            EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200), @PlainPassword)),
            @RoleName, @Clearance);

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ValidateLogin
    @Username      NVARCHAR(50),
    @PlainPassword NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    DECLARE @Stored VARBINARY(256);
    SELECT @Stored = PasswordEnc FROM dbo.[Users] WHERE Username = @Username;

    IF @Stored IS NULL
    BEGIN
        CLOSE SYMMETRIC KEY SRMS_AES_Key;
        THROW 50002, 'Invalid login.', 1;
    END

    DECLARE @Decrypted NVARCHAR(200);
    SELECT @Decrypted = CONVERT(NVARCHAR(200), DecryptByKey(@Stored));

    CLOSE SYMMETRIC KEY SRMS_AES_Key;

    IF @Decrypted <> @PlainPassword
        THROW 50002, 'Invalid login.', 1;

    SELECT Username,
           RoleName,
           ClearanceLevel
    FROM dbo.[Users]
    WHERE Username = @Username;
END
GO

/* ===== Public Course Info (Guest allowed) (PDF Security Matrix) :contentReference[oaicite:18]{index=18} */
CREATE OR ALTER PROCEDURE dbo.usp_ViewPublicCourses
    @Username NVARCHAR(50)
AS                                                       
BEGIN
    SET NOCOUNT ON;

    -- any valid user role can view public course info
    IF dbo.fn_UserRole(@Username) IS NULL
        THROW 50003, 'Access denied: unknown user.', 1;

    SELECT CourseID, CourseName, PublicInfo
    FROM dbo.Course;
END
GO

/* ===== Student profile (Confidential) ===== */
CREATE OR ALTER PROCEDURE dbo.usp_ViewOwnProfile
    @Username NVARCHAR(50),
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    -- MLS: No Read Up (Confidential=2)
    IF @clr < 2
        THROW 50004, 'MLS NRU: insufficient clearance for Student profile.', 1;

    -- Student can only view own profile, others (Admin/Instructor/TA) can view any
    IF @role = 'Student'
    BEGIN
        -- mapping assumption: student username = email prefix not enforced;
        -- enforce by checking StudentID exists and username is assigned in Users via same Username
        -- simplest safe rule: Student may only view StudentID that matches their own record by email = username OR username = email
        IF NOT EXISTS (SELECT 1 FROM dbo.Student WHERE StudentID=@StudentID AND Email=@Username)
            THROW 50005, 'Access denied: Student can view only own profile.', 1;
    END

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    SELECT StudentID, FullName, Email,
           CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
           DOB, Department, ClearanceLevel
    FROM dbo.Student
    WHERE StudentID = @StudentID;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_EditOwnProfile
    @Username NVARCHAR(50),
    @StudentID INT,
    @FullName NVARCHAR(100),
    @Phone NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    -- Only Admin/Instructor/TA can edit any, Student cannot edit (matrix: Student ? edit) :contentReference[oaicite:19]{index=19}
    IF @role NOT IN ('Admin','Instructor','TA')
        THROW 50006, 'Access denied: Only Admin/Instructor/TA can edit profile.', 1;

    -- MLS: No Write Down (BONUS) — Confidential target=2; block clearance >2 writing down
    IF @clr > 2
        THROW 50007, 'MLS NWD: higher clearance cannot write to lower classification.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    UPDATE dbo.Student
    SET FullName = @FullName,
        PhoneEnc = EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), @Phone))
    WHERE StudentID=@StudentID;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

/* ===== Grades (Secret) — view/edit only Admin & Instructor (matrix) :contentReference[oaicite:20]{index=20} ===== */
CREATE OR ALTER PROCEDURE dbo.usp_EnterOrUpdateGrade
    @Username NVARCHAR(50),
    @StudentID INT,
    @CourseID INT,
    @GradeValue DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    IF @role NOT IN ('Admin','Instructor')
        THROW 50008, 'Access denied: Only Admin/Instructor can edit grades.', 1;

    -- MLS: No Read Up/Write checks (Secret=3)
    IF @clr < 3
        THROW 50009, 'MLS NRU: insufficient clearance for Secret grades.', 1;

    -- MLS: No Write Down (BONUS) — target Secret=3; block clearance >3 writing down
    IF @clr > 3
        THROW 50010, 'MLS NWD: higher clearance cannot write to lower classification.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    IF EXISTS (SELECT 1 FROM dbo.Grades WHERE StudentID=@StudentID AND CourseID=@CourseID)
    BEGIN
        UPDATE dbo.Grades
        SET GradeValueEnc = EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(32), @GradeValue)),
            DateEntered = GETDATE(),
            EnteredBy = @Username
        WHERE StudentID=@StudentID AND CourseID=@CourseID;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Grades(StudentID, CourseID, GradeValueEnc, DateEntered, EnteredBy)
        VALUES (@StudentID, @CourseID,
                EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(32), @GradeValue)),
                GETDATE(), @Username);
    END

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ViewGrades
    @Username NVARCHAR(50),
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    -- Only Admin/Instructor can view grades (matrix) :contentReference[oaicite:21]{index=21}
    IF @role NOT IN ('Admin','Instructor')
        THROW 50011, 'Access denied: Only Admin/Instructor can view grades.', 1;

    IF @clr < 3
        THROW 50012, 'MLS NRU: insufficient clearance for Secret grades.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    SELECT g.GradeID, g.StudentID, g.CourseID,
           CONVERT(DECIMAL(5,2), CONVERT(NVARCHAR(32), DecryptByKey(g.GradeValueEnc))) AS GradeValue,
           g.DateEntered, g.EnteredBy
    FROM dbo.Grades g
    WHERE g.StudentID = @StudentID;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

/* ===== Attendance (Secret) — view/edit Admin/Instructor/TA; Student own view only (matrix) :contentReference[oaicite:22]{index=22} ===== */
CREATE OR ALTER PROCEDURE dbo.usp_RecordAttendance
    @Username NVARCHAR(50),
    @StudentID INT,
    @CourseID INT,
    @Status BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    IF @role NOT IN ('Admin','Instructor','TA')
        THROW 50013, 'Access denied: Only Admin/Instructor/TA can edit attendance.', 1;

    IF @clr < 3
        THROW 50014, 'MLS NRU: insufficient clearance for Secret attendance.', 1;

    -- MLS: No Write Down (BONUS) — target Secret=3; block clearance >3 writing down
    IF @clr > 3
        THROW 50015, 'MLS NWD: higher clearance cannot write to lower classification.', 1;

    INSERT INTO dbo.Attendance(StudentID, CourseID, [Status], DateRecorded, RecordedBy)
    VALUES (@StudentID, @CourseID, @Status, GETDATE(), @Username);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ViewAttendance
    @Username NVARCHAR(50),
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    IF @clr < 3
        THROW 50016, 'MLS NRU: insufficient clearance for Secret attendance.', 1;

    IF @role IN ('Admin','Instructor','TA')
    BEGIN
        SELECT AttendanceID, StudentID, CourseID, [Status], DateRecorded, RecordedBy
        FROM dbo.Attendance
        WHERE StudentID=@StudentID;
        RETURN;
    END

    -- Student can view own attendance only (matrix) :contentReference[oaicite:23]{index=23}
    IF @role = 'Student'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.Student WHERE StudentID=@StudentID AND Email=@Username)
            THROW 50017, 'Access denied: Student can view only own attendance.', 1;

        SELECT AttendanceID, StudentID, CourseID, [Status], DateRecorded
        FROM dbo.Attendance
        WHERE StudentID=@StudentID;
        RETURN;
    END;

    THROW 50018, 'Access denied.', 1;
END
GO

/* ===== Admin manage users (matrix) :contentReference[oaicite:24]{index=24} ===== */
CREATE OR ALTER PROCEDURE dbo.usp_UpdateUserRole
    @AdminUser NVARCHAR(50),
    @TargetUser NVARCHAR(50),
    @NewRole NVARCHAR(20),
    @NewClearance INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_UserRole(@AdminUser) <> 'Admin'
        THROW 50019, 'Access denied: Admin only.', 1;

    UPDATE dbo.[Users]
    SET RoleName = @NewRole,
        ClearanceLevel = @NewClearance
    WHERE Username = @TargetUser;
END
GO

---------------------------------------------------------------
-- TASK 6: Inference Control (min group size=3) + restricted views (PDF 4.2) :contentReference[oaicite:25]{index=25}
---------------------------------------------------------------

/* Restricted Views:
   - TA/Student should not see Grades (matrix), and Student sees only own in GUI.
   - Provide a limited student view without phone encryption details for lower roles.
*/
CREATE OR ALTER VIEW dbo.vw_TA_Student_RestrictedStudent
AS
SELECT StudentID, FullName, Department
FROM dbo.Student;
GO

/* Query Set Size Control (min group size=3):
   Blocks aggregates that could reveal identity.
*/
CREATE OR ALTER PROCEDURE dbo.usp_AvgGradeByDepartment
    @Username NVARCHAR(50),
    @Department NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);
    DECLARE @clr  INT = dbo.fn_UserClearance(@Username);

    -- Only Admin/Instructor can run aggregates on Secret grades
    IF @role NOT IN ('Admin','Instructor')
        THROW 50020, 'Access denied.', 1;

    IF @clr < 3
        THROW 50021, 'MLS NRU: insufficient clearance.', 1;

    DECLARE @cnt INT;

    SELECT @cnt = COUNT(DISTINCT s.StudentID)
    FROM dbo.Student s
    JOIN dbo.Grades g ON g.StudentID = s.StudentID
    WHERE s.Department = @Department;

    IF @cnt < 3
        THROW 50022, 'Inference Control: group size < 3 (blocked).', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    SELECT s.Department,
           AVG(CONVERT(DECIMAL(5,2), CONVERT(NVARCHAR(32), DecryptByKey(g.GradeValueEnc)))) AS AvgGrade,
           COUNT(DISTINCT s.StudentID) AS GroupSize
    FROM dbo.Student s
    JOIN dbo.Grades g ON g.StudentID = s.StudentID
    WHERE s.Department = @Department
    GROUP BY s.Department;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

---------------------------------------------------------------
-- TASK 7: Flow Control (Prevent Downflow) (PDF 4.3) :contentReference[oaicite:26]{index=26}
-- Enforced by:
-- 1) Permissions: Secret tables never selectable by Student/Guest/TA for grades
-- 2) Procedures: Secret ops require clearance>=3 and role checks
---------------------------------------------------------------

---------------------------------------------------------------
-- TASK 8: MLS (Bell–LaPadula NRU + NWD bonus) (PDF 4.4) :contentReference[oaicite:27]{index=27}
-- Implemented inside procedures:
-- - NRU: clearance check before reading confidential/secret
-- - NWD bonus: block writing to lower classification targets
---------------------------------------------------------------

---------------------------------------------------------------
-- TASK 9: Part B – Role Upgrade Request Workflow (PDF Part B) :contentReference[oaicite:28]{index=28}
---------------------------------------------------------------

CREATE TABLE dbo.RoleRequests (
    RequestID       INT IDENTITY(1,1) PRIMARY KEY,
    Username        NVARCHAR(50) NOT NULL,
    CurrentRole     NVARCHAR(20) NOT NULL,
    RequestedRole   NVARCHAR(20) NOT NULL,
    Reason          NVARCHAR(400) NOT NULL,
    Comments        NVARCHAR(400) NULL,
    Status          NVARCHAR(20) NOT NULL CHECK (Status IN ('Pending','Approved','Denied')),
    DateSubmitted   DATETIME NOT NULL,
    DateResolved    DATETIME NULL,
    ResolvedBy      NVARCHAR(50) NULL
);
GO

-- Student submits request (no auto role change) (PDF Part B.1) :contentReference[oaicite:29]{index=29}
CREATE OR ALTER PROCEDURE dbo.usp_SubmitRoleUpgradeRequest
    @Username NVARCHAR(50),
    @RequestedRole NVARCHAR(20),
    @Reason NVARCHAR(400),
    @Comments NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.fn_UserRole(@Username);

    -- lower-privileged users request upgrades (Student/TA) per PDF examples
    IF @role NOT IN ('Student','TA')
        THROW 50030, 'Access denied: Only Student/TA can submit upgrade requests.', 1;

    INSERT INTO dbo.RoleRequests(Username, CurrentRole, RequestedRole, Reason, Comments, Status, DateSubmitted)
    VALUES (@Username, @role, @RequestedRole, @Reason, @Comments, 'Pending', GETDATE());
END
GO

-- Admin dashboard lists pending requests (PDF Part B.2) :contentReference[oaicite:30]{index=30}
CREATE OR ALTER PROCEDURE dbo.usp_ListPendingRoleRequests
    @AdminUser NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_UserRole(@AdminUser) <> 'Admin'
        THROW 50031, 'Access denied: Admin only.', 1;

    SELECT RequestID, Username, CurrentRole, RequestedRole, Reason, DateSubmitted, Status
    FROM dbo.RoleRequests
    WHERE Status = 'Pending'
    ORDER BY DateSubmitted;
END
GO

-- Admin approves/denies (PDF Part B.2) :contentReference[oaicite:31]{index=31}
CREATE OR ALTER PROCEDURE dbo.usp_ResolveRoleRequest
    @AdminUser NVARCHAR(50),
    @RequestID INT,
    @Action NVARCHAR(10),   -- 'Approve' or 'Deny'
    @NewClearance INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_UserRole(@AdminUser) <> 'Admin'
        THROW 50032, 'Access denied: Admin only.', 1;

    DECLARE @Username NVARCHAR(50), @RequestedRole NVARCHAR(20), @CurrentStatus NVARCHAR(20);

    SELECT @Username = Username,
           @RequestedRole = RequestedRole,
           @CurrentStatus = Status
    FROM dbo.RoleRequests
    WHERE RequestID = @RequestID;

    IF @CurrentStatus <> 'Pending'
        THROW 50033, 'Request already resolved.', 1;

    IF @Action = 'Approve'
    BEGIN
        UPDATE dbo.[Users]
        SET RoleName = @RequestedRole,
            ClearanceLevel = COALESCE(@NewClearance, ClearanceLevel)
        WHERE Username = @Username;

        UPDATE dbo.RoleRequests
        SET Status='Approved',
            DateResolved=GETDATE(),
            ResolvedBy=@AdminUser
        WHERE RequestID=@RequestID;
    END
    ELSE IF @Action = 'Deny'
    BEGIN
        UPDATE dbo.RoleRequests
        SET Status='Denied',
            DateResolved=GETDATE(),
            ResolvedBy=@AdminUser
        WHERE RequestID=@RequestID;
    END
    ELSE
        THROW 50034, 'Invalid action. Use Approve/Deny.', 1;
END
GO

---------------------------------------------------------------
-- TASK 10: Grant EXECUTE on procedures based on roles (RBAC) (PDF 4.1 + matrix) :contentReference[oaicite:32]{index=32}
---------------------------------------------------------------

-- Everyone (Guest included) can view public course info
GRANT EXECUTE ON dbo.usp_ViewPublicCourses TO [Guest];
GRANT EXECUTE ON dbo.usp_ViewPublicCourses TO [Student];
GRANT EXECUTE ON dbo.usp_ViewPublicCourses TO [TA];
GRANT EXECUTE ON dbo.usp_ViewPublicCourses TO [Instructor];
GRANT EXECUTE ON dbo.usp_ViewPublicCourses TO [Admin];

-- Profile view
GRANT EXECUTE ON dbo.usp_ViewOwnProfile TO [Student];
GRANT EXECUTE ON dbo.usp_ViewOwnProfile TO [TA];
GRANT EXECUTE ON dbo.usp_ViewOwnProfile TO [Instructor];
GRANT EXECUTE ON dbo.usp_ViewOwnProfile TO [Admin];

-- Profile edit only Admin/Instructor/TA (matrix)
GRANT EXECUTE ON dbo.usp_EditOwnProfile TO [TA];
GRANT EXECUTE ON dbo.usp_EditOwnProfile TO [Instructor];
GRANT EXECUTE ON dbo.usp_EditOwnProfile TO [Admin];

-- Grades view/edit only Admin/Instructor (matrix)
GRANT EXECUTE ON dbo.usp_ViewGrades TO [Instructor];
GRANT EXECUTE ON dbo.usp_ViewGrades TO [Admin];
GRANT EXECUTE ON dbo.usp_EnterOrUpdateGrade TO [Instructor];
GRANT EXECUTE ON dbo.usp_EnterOrUpdateGrade TO [Admin];

-- Attendance view/edit Admin/Instructor/TA; student view own via usp_ViewAttendance
GRANT EXECUTE ON dbo.usp_RecordAttendance TO [TA];
GRANT EXECUTE ON dbo.usp_RecordAttendance TO [Instructor];
GRANT EXECUTE ON dbo.usp_RecordAttendance TO [Admin];
GRANT EXECUTE ON dbo.usp_ViewAttendance TO [Student];
GRANT EXECUTE ON dbo.usp_ViewAttendance TO [TA];
GRANT EXECUTE ON dbo.usp_ViewAttendance TO [Instructor];
GRANT EXECUTE ON dbo.usp_ViewAttendance TO [Admin];

-- Admin manage users
GRANT EXECUTE ON dbo.usp_CreateUser TO [Admin];
GRANT EXECUTE ON dbo.usp_UpdateUserRole TO [Admin];
GRANT EXECUTE ON dbo.usp_ListPendingRoleRequests TO [Admin];
GRANT EXECUTE ON dbo.usp_ResolveRoleRequest TO [Admin];

-- Inference control aggregate only Admin/Instructor
GRANT EXECUTE ON dbo.usp_AvgGradeByDepartment TO [Instructor];
GRANT EXECUTE ON dbo.usp_AvgGradeByDepartment TO [Admin];

-- Role request submit (Student/TA)
GRANT EXECUTE ON dbo.usp_SubmitRoleUpgradeRequest TO [Student];
GRANT EXECUTE ON dbo.usp_SubmitRoleUpgradeRequest TO [TA];
GO

---------------------------------------------------------------
-- TASK 11: Example seed users (optional for testing)
---------------------------------------------------------------
OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

INSERT INTO dbo.[Users](Username,PasswordEnc,RoleName,ClearanceLevel) VALUES
('admin1', EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200),'adminpass')), 'Admin', 4),
('inst1',  EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200),'instpass')),  'Instructor', 3),
('ta1',    EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200),'tapass')),    'TA', 3),
('stud1@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200),'studpass')), 'Student', 2),
('guest1', EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200),'guestpass')), 'Guest', 1);

CLOSE SYMMETRIC KEY SRMS_AES_Key;
GO

---------------------------------------------------------------
-- TASK 12: Add DB users & assign SQL roles (for DB-level testing)
---------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='admin1')
    CREATE USER [admin1] WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='inst1')
    CREATE USER [inst1] WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='ta1')
    CREATE USER [ta1] WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='stud1@nu.edu')
    CREATE USER [stud1@nu.edu] WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='guest1')
    CREATE USER [guest1] WITHOUT LOGIN;
GO

EXEC sp_addrolemember 'Admin',      'admin1';
EXEC sp_addrolemember 'Instructor', 'inst1';
EXEC sp_addrolemember 'TA',         'ta1';
EXEC sp_addrolemember 'Student',    'stud1@nu.edu';
EXEC sp_addrolemember 'Guests',      'guest1';
GO



-- ????? ?? admin1 ?????
EXEC dbo.usp_CreateUser
    'admin1', 'admin2', 'admin123', 'Admin', 4;
