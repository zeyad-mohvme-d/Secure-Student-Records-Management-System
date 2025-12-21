/* ============================================================
   Database Security – Term Project (Phase 2)
   Secure Student Records Management System (SRMS)
   FULLY COMPLIANT WITH INSTRUCTIONS INCLUDING:
   - Encrypted Student ID (PDF 3.1)
   - RBAC + MLS + Inference + Flow + Encryption
   - Part B: Role Request Workflow
   ============================================================ */

---------------------------------------------------------------
-- TASK 0: Create Database
---------------------------------------------------------------
USE [master];

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
-- TASK 1: Encryption Setup (AES)
---------------------------------------------------------------
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Yassin!2025';
GO

CREATE CERTIFICATE SRMS_Cert
WITH SUBJECT = 'SRMS AES Certificate';
GO

CREATE SYMMETRIC KEY SRMS_AES_Key
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE SRMS_Cert;
GO

---------------------------------------------------------------
-- TASK 2: Required Schema (WITH Encrypted Student ID)
---------------------------------------------------------------

-- STUDENT (Confidential): StudentID is encrypted; SurrogateID used for PK/FK
CREATE TABLE dbo.Student (
    SurrogateID     INT IDENTITY(1,1) PRIMARY KEY,  -- used for FKs
    StudentID_Enc   VARBINARY(256) NOT NULL,        -- REAL Student ID, encrypted (PDF 3.1)
    FullName        NVARCHAR(100)  NOT NULL,
    Email           NVARCHAR(100)  NOT NULL UNIQUE, -- link to Users.Username
    PhoneEnc        VARBINARY(256) NOT NULL,
    DOB             DATE           NOT NULL,
    Department      NVARCHAR(50)   NOT NULL,
    ClearanceLevel  INT            NOT NULL CHECK (ClearanceLevel BETWEEN 1 AND 4)
);
GO

-- INSTRUCTOR (Confidential)
CREATE TABLE dbo.Instructor (
    InstructorID    INT            NOT NULL PRIMARY KEY,
    FullName        NVARCHAR(100)  NOT NULL,
    Email           NVARCHAR(100)  NOT NULL,
    ClearanceLevel  INT            NOT NULL CHECK (ClearanceLevel BETWEEN 1 AND 4)
);
GO

-- COURSE (Unclassified)
CREATE TABLE dbo.Course (
    CourseID    INT            NOT NULL PRIMARY KEY,
    CourseName  NVARCHAR(100)  NOT NULL,
    [Description] NVARCHAR(MAX) NULL,
    PublicInfo  NVARCHAR(MAX)  NULL
);
GO

-- GRADES (Secret): FK to Student.SurrogateID
CREATE TABLE dbo.Grades (
    GradeID         INT            IDENTITY(1,1) PRIMARY KEY,
    StudentRefID    INT            NOT NULL,  -- FK to Student.SurrogateID
    CourseID        INT            NOT NULL,
    GradeValueEnc   VARBINARY(256) NOT NULL,
    DateEntered     DATETIME       NOT NULL,
    EnteredBy       NVARCHAR(50)   NOT NULL,
    CONSTRAINT FK_Grades_Student FOREIGN KEY (StudentRefID) REFERENCES dbo.Student(SurrogateID),
    CONSTRAINT FK_Grades_Course  FOREIGN KEY (CourseID)     REFERENCES dbo.Course(CourseID)
);
GO

-- ATTENDANCE (Secret)
CREATE TABLE dbo.Attendance (
    AttendanceID    INT IDENTITY(1,1) PRIMARY KEY,
    StudentRefID    INT NOT NULL,  -- FK to Student.SurrogateID
    CourseID        INT NOT NULL,
    [Status]        BIT NOT NULL,
    DateRecorded    DATETIME NOT NULL,
    RecordedBy      NVARCHAR(50) NOT NULL,
    CONSTRAINT FK_Att_Student FOREIGN KEY (StudentRefID) REFERENCES dbo.Student(SurrogateID),
    CONSTRAINT FK_Att_Course  FOREIGN KEY (CourseID)     REFERENCES dbo.Course(CourseID)
);
GO

-- USERS (Authentication)
CREATE TABLE dbo.Users (
    Username        NVARCHAR(50)   NOT NULL PRIMARY KEY,  -- e.g., email for students
    PasswordEnc     VARBINARY(256) NOT NULL,
    RoleName        NVARCHAR(20)   NOT NULL CHECK (RoleName IN ('Admin','Instructor','TA','Student','Guest')),
    ClearanceLevel  INT            NOT NULL CHECK (ClearanceLevel BETWEEN 1 AND 4)
);
GO

---------------------------------------------------------------
-- TASK 3: RBAC Roles + Block Direct Table Access
---------------------------------------------------------------
CREATE ROLE [Admin];
CREATE ROLE [Instructor];
CREATE ROLE [TA];
CREATE ROLE [Student];
CREATE ROLE [GuestUser];
GO

-- Deny all direct table access
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO PUBLIC;
GO

---------------------------------------------------------------
-- TASK 4: Helper Functions
---------------------------------------------------------------
CREATE OR ALTER FUNCTION UserRole(@Username NVARCHAR(50))
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @r NVARCHAR(20);
    SELECT @r = RoleName FROM Users WHERE Username = @Username;
    RETURN @r;
END
GO

CREATE OR ALTER FUNCTION UserClearance(@Username NVARCHAR(50))
RETURNS INT
AS
BEGIN
    DECLARE @c INT;
    SELECT @c = ClearanceLevel FROM dbo.Users WHERE Username = @Username;
    RETURN @c;
END
GO

-- Helper: Get Student SurrogateID from Username (for Students)
CREATE OR ALTER FUNCTION GetStudentSurrogateID(@Username NVARCHAR(50))
RETURNS INT
AS
BEGIN
    DECLARE @sid INT;
    SELECT @sid = SurrogateID FROM Student WHERE Email = @Username;
    RETURN @sid;
END
GO

---------------------------------------------------------------
-- TASK 5: Stored Procedures (ALL OPERATIONS)
---------------------------------------------------------------

-- Authentication
CREATE OR ALTER PROCEDURE CreateUser
    @AdminUser     NVARCHAR(50),
    @Username      NVARCHAR(50),
    @PlainPassword NVARCHAR(200),
    @RoleName      NVARCHAR(20),
    @Clearance     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.UserRole(@AdminUser) <> 'Admin'
    BEGIN
        THROW 50001, 'Admin only.', 1;
    END

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    INSERT INTO dbo.Users (Username, PasswordEnc, RoleName, ClearanceLevel)
    VALUES (@Username,
            EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(200), @PlainPassword)),
            @RoleName,
            @Clearance);

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO


CREATE OR ALTER PROCEDURE ValidateLogin
    @Username      NVARCHAR(50),
    @PlainPassword NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;
    DECLARE @Stored VARBINARY(256);
    SELECT @Stored = PasswordEnc FROM dbo.[Users] WHERE Username = @Username;
    IF @Stored IS NULL BEGIN CLOSE SYMMETRIC KEY SRMS_AES_Key; THROW 50002, 'Invalid login.', 1; END
    DECLARE @Decrypted NVARCHAR(200) = CONVERT(NVARCHAR(200), DecryptByKey(@Stored));
    CLOSE SYMMETRIC KEY SRMS_AES_Key;
    IF @Decrypted <> @PlainPassword THROW 50002, 'Invalid login.', 1;
    SELECT Username, RoleName, ClearanceLevel FROM dbo.Users WHERE Username = @Username;
END
GO


CREATE OR ALTER PROCEDURE ViewOwnProfile @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);
    IF @clr < 2 THROW 50004, 'MLS NRU: clearance < Confidential.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    IF @role = 'Student'
    BEGIN
        SELECT 
            CONVERT(NVARCHAR(20), DecryptByKey(StudentID_Enc)) AS StudentID,
            FullName, Email,
            CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
            DOB, Department, ClearanceLevel
        FROM dbo.Student
        WHERE Email = @Username;
    END
    ELSE
    BEGIN
        -- Admin/Instructor/TA: return all (but still encrypted!)
        SELECT 
            CONVERT(NVARCHAR(20), DecryptByKey(StudentID_Enc)) AS StudentID,
            FullName, Email,
            CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
            DOB, Department, ClearanceLevel
        FROM dbo.Student;
    END

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

-- Public Courses
CREATE OR ALTER PROCEDURE ViewPublicCourses @Username NVARCHAR(50)
AS
BEGIN
    IF dbo.UserRole(@Username) IS NULL THROW 50003, 'Unknown user.', 1;
    SELECT CourseID, CourseName, PublicInfo FROM dbo.Course;
END
GO

-- 
CREATE OR ALTER PROCEDURE ViewProfilesByRole
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);

    IF @role IS NULL
        THROW 50100, 'Unknown user.', 1;

    -- =========================
    -- STUDENT: Self only
    -- =========================
    IF @role = 'Student'
    BEGIN
        IF @clr < 2 THROW 50101, 'MLS NRU.', 1;

        OPEN SYMMETRIC KEY SRMS_AES_Key
        DECRYPTION BY CERTIFICATE SRMS_Cert;

        SELECT
            'Student' AS ProfileType,
            CONVERT(NVARCHAR(20), DecryptByKey(StudentID_Enc)) AS Identifier,
            FullName,
            Email,
            CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
            Department,
            ClearanceLevel
        FROM dbo.Student
        WHERE Email = @Username;

        CLOSE SYMMETRIC KEY SRMS_AES_Key;
        RETURN;
    END

    -- =========================
    -- TA: Students only
    -- =========================
    IF @role = 'TA'
    BEGIN
        IF @clr < 3 THROW 50102, 'MLS NRU.', 1;

        OPEN SYMMETRIC KEY SRMS_AES_Key
        DECRYPTION BY CERTIFICATE SRMS_Cert;

        SELECT
            'Student' AS ProfileType,
            CONVERT(NVARCHAR(20), DecryptByKey(StudentID_Enc)) AS Identifier,
            FullName,
            Email,
            CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
            Department,
            ClearanceLevel
        FROM dbo.Student;

        CLOSE SYMMETRIC KEY SRMS_AES_Key;
        RETURN;
    END

    -- =========================
    -- INSTRUCTOR: TAs + Students
    -- =========================
    IF @role = 'Instructor'
    BEGIN
        IF @clr < 3 THROW 50103, 'MLS NRU.', 1;

        OPEN SYMMETRIC KEY SRMS_AES_Key
        DECRYPTION BY CERTIFICATE SRMS_Cert;

        -- Students
        SELECT
            'Student' AS ProfileType,
            CONVERT(NVARCHAR(20), DecryptByKey(StudentID_Enc)) AS Identifier,
            FullName,
            Email,
            CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
            Department,
            ClearanceLevel
        FROM dbo.Student

        UNION ALL

        -- TAs (from Users)
        SELECT
            'TA' AS ProfileType,
            NULL AS Identifier,
            Username AS FullName,
            Username AS Email,
            NULL AS Phone,
            NULL AS Department,
            ClearanceLevel
        FROM dbo.Users
        WHERE RoleName = 'TA';

        CLOSE SYMMETRIC KEY SRMS_AES_Key;
        RETURN;
    END

    -- =========================
    -- ADMIN: Users + Instructors + Students
    -- =========================
    IF @role = 'Admin'
    BEGIN
        IF @clr < 4 THROW 50104, 'MLS NRU.', 1;

        OPEN SYMMETRIC KEY SRMS_AES_Key
        DECRYPTION BY CERTIFICATE SRMS_Cert;

        SELECT
            'Student' AS ProfileType,
            CONVERT(NVARCHAR(20), DecryptByKey(StudentID_Enc)) AS Identifier,
            FullName,
            Email,
            CONVERT(NVARCHAR(20), DecryptByKey(PhoneEnc)) AS Phone,
            Department,
            ClearanceLevel
        FROM dbo.Student

        UNION ALL

        SELECT
            'Instructor',
            NULL,
            Username,
            Username,
            NULL,
            NULL,
            ClearanceLevel
        FROM dbo.Users
        WHERE RoleName = 'Instructor'

        UNION ALL

        SELECT
            'User',
            NULL,
            Username,
            Username,
            NULL,
            NULL,
            ClearanceLevel
        FROM dbo.Users;

        CLOSE SYMMETRIC KEY SRMS_AES_Key;
        RETURN;
    END
    ELSE
    BEGIN
        THROW 50105, 'Access denied.', 1;
    END
END
GO

CREATE OR ALTER PROCEDURE EditOwnProfile
    @Username NVARCHAR(50),
    @NewFullName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);

    -- Only Admin / Instructor / TA
    IF @role NOT IN ('Admin','Instructor','TA')
        THROW 50006, 'Only Admin/Instructor/TA can edit profile.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key
        DECRYPTION BY CERTIFICATE SRMS_Cert;

    UPDATE dbo.Student
    SET 
        FullName = @NewFullName,
        ClearanceLevel = @clr   -- MLS-safe
    WHERE Email = @Username;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO


-- Grades
CREATE OR ALTER PROCEDURE EnterOrUpdateGrade
     @Username NVARCHAR(50),
    @StudentEmail NVARCHAR(100),
    @CourseID INT,
    @GradeValue DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);
    IF @role NOT IN ('Admin','Instructor') THROW 50008, 'Only Admin/Instructor can edit grades.', 1;
    IF @clr < 3 THROW 50009, 'MLS NRU: clearance < Secret.', 1;
    IF @clr > 3 AND @role <> 'Admin'
		THROW 50010, 'MLS NWD: cannot write down.', 1;

    DECLARE @StudentRefID INT = (SELECT SurrogateID FROM dbo.Student WHERE Email = @StudentEmail);
    IF @StudentRefID IS NULL THROW 50025, 'Student not found.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    IF EXISTS (SELECT 1 FROM dbo.Grades WHERE StudentRefID = @StudentRefID AND CourseID = @CourseID)
    BEGIN
        UPDATE dbo.Grades
        SET GradeValueEnc = EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(MAX), CAST(@GradeValue AS NVARCHAR(20)))),
            DateEntered = GETDATE(), EnteredBy = @Username
        WHERE StudentRefID = @StudentRefID AND CourseID = @CourseID;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Grades(StudentRefID, CourseID, GradeValueEnc, DateEntered, EnteredBy)
        VALUES (@StudentRefID, @CourseID, EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(MAX), CAST(@GradeValue AS NVARCHAR(20)))), GETDATE(), @Username);
    END

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

CREATE OR ALTER PROCEDURE ViewGrades
        @Username NVARCHAR(50), 
        @StudentEmail NVARCHAR(100)
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
        DECLARE @clr  INT = dbo.UserClearance(@Username);
        IF @role NOT IN ('Admin','Instructor') THROW 50011, 'Only Admin/Instructor can view grades.', 1;
        IF @clr < 3 THROW 50012, 'MLS NRU: clearance < Secret.', 1;

        DECLARE @StudentRefID INT = (SELECT SurrogateID FROM dbo.Student WHERE Email = @StudentEmail);
        IF @StudentRefID IS NULL THROW 50025, 'Student not found.', 1;

        OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

        SELECT 
            g.GradeID,
            (SELECT CONVERT(NVARCHAR(20), DecryptByKey(s2.StudentID_Enc)) FROM dbo.Student s2 WHERE s2.SurrogateID = g.StudentRefID) AS StudentID,
            g.CourseID,
            CAST(CONVERT(NVARCHAR(MAX), DecryptByKey(g.GradeValueEnc)) AS DECIMAL(5,2)) AS GradeValue,
            g.DateEntered, g.EnteredBy
        FROM dbo.Grades g
        WHERE g.StudentRefID = @StudentRefID;

        CLOSE SYMMETRIC KEY SRMS_AES_Key;
    END
    GO

-- Attendance
CREATE OR ALTER PROCEDURE RecordAttendance
    @Username NVARCHAR(50),
    @StudentEmail NVARCHAR(100),
    @CourseID INT,
    @Status BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);
    IF @role NOT IN ('Admin','Instructor','TA') THROW 50013, 'Only Admin/Instructor/TA can edit attendance.', 1;
    IF @clr < 3 THROW 50014, 'MLS NRU: clearance < Secret.', 1;
    IF @clr > 3 THROW 50015, 'MLS NWD: cannot write down.', 1;

    DECLARE @StudentRefID INT = (SELECT SurrogateID FROM dbo.Student WHERE Email = @StudentEmail);
    IF @StudentRefID IS NULL THROW 50025, 'Student not found.', 1;

    INSERT INTO dbo.Attendance(StudentRefID, CourseID, Status, DateRecorded, RecordedBy)
    VALUES (@StudentRefID, @CourseID, @Status, GETDATE(), @Username);
END
GO

CREATE OR ALTER PROCEDURE ViewAttendance @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);
    IF @clr < 3 AND dbo.UserRole(@Username) <> 'Student'
		THROW 50016, 'MLS NRU: clearance < Secret.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    IF @role IN ('Admin','Instructor','TA')
    BEGIN
        SELECT 
            a.AttendanceID,
            (SELECT CONVERT(NVARCHAR(20), DecryptByKey(s.StudentID_Enc)) FROM dbo.Student s WHERE s.SurrogateID = a.StudentRefID) AS StudentID,
            a.CourseID, a.[Status], a.DateRecorded, a.RecordedBy
        FROM dbo.Attendance a;
    END
    ELSE IF @role = 'Student'
    BEGIN
        DECLARE @MyRefID INT = dbo.GetStudentSurrogateID(@Username);
        IF @MyRefID IS NULL THROW 50017, 'Student record not found.', 1;

        SELECT 
            AttendanceID,
            (SELECT CONVERT(NVARCHAR(20), DecryptByKey(s.StudentID_Enc)) FROM dbo.Student s WHERE s.SurrogateID = a.StudentRefID) AS StudentID,
            CourseID, [Status], DateRecorded
        FROM dbo.Attendance a
        WHERE a.StudentRefID = @MyRefID;
    END
    ELSE
        THROW 50018, 'Access denied.', 1;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

-- Admin: Manage Users
CREATE OR ALTER PROCEDURE UpdateUserRole
    @AdminUser NVARCHAR(50),
    @TargetUser NVARCHAR(50),
    @NewRole NVARCHAR(20),
    @NewClearance INT
AS
BEGIN
    IF dbo.UserRole(@AdminUser) <> 'Admin' THROW 50019, 'Admin only.', 1;
    UPDATE dbo.[Users] SET RoleName = @NewRole, ClearanceLevel = @NewClearance WHERE Username = @TargetUser;
END
GO

---------------------------------------------------------------
-- TASK 6: Inference Control (min group size = 3)
---------------------------------------------------------------
CREATE OR ALTER VIEW TA_Student_RestrictedStudent
AS
SELECT SurrogateID, FullName, Department FROM dbo.Student;
GO

CREATE OR ALTER PROCEDURE AvgGradeByDepartment
    @Username NVARCHAR(50),
    @Department NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @role NVARCHAR(20) = dbo.UserRole(@Username);
    DECLARE @clr  INT = dbo.UserClearance(@Username);
    IF @role NOT IN ('Admin','Instructor') THROW 50020, 'Access denied.', 1;
    IF @clr < 3 THROW 50021, 'MLS NRU.', 1;

    DECLARE @cnt INT;
    SELECT @cnt = COUNT(DISTINCT s.SurrogateID)
    FROM dbo.Student s JOIN dbo.Grades g ON g.StudentRefID = s.SurrogateID
    WHERE s.Department = @Department;

    IF @cnt < 3 THROW 50022, 'Inference Control: group size < 3.', 1;

    OPEN SYMMETRIC KEY SRMS_AES_Key DECRYPTION BY CERTIFICATE SRMS_Cert;

    SELECT 
        s.Department,
        AVG(CONVERT(DECIMAL(5,2), CONVERT(NVARCHAR(32), DecryptByKey(g.GradeValueEnc)))) AS AvgGrade,
        COUNT(DISTINCT s.SurrogateID) AS GroupSize
    FROM dbo.Student s
    JOIN dbo.Grades g ON g.StudentRefID = s.SurrogateID
    WHERE s.Department = @Department
    GROUP BY s.Department;

    CLOSE SYMMETRIC KEY SRMS_AES_Key;
END
GO

---------------------------------------------------------------
-- TASK 7-8: Flow Control + MLS
-- Already enforced in all procedures via role + clearance checks + NWD logic.
---------------------------------------------------------------

---------------------------------------------------------------
-- TASK 9: Part B – Role Upgrade Requests
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

CREATE OR ALTER PROCEDURE dbo.SubmitRoleUpgradeRequest
    @Username NVARCHAR(50),
    @RequestedRole NVARCHAR(20),
    @Reason NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentRole NVARCHAR(20) = dbo.UserRole(@Username);

    IF @CurrentRole IS NULL
        THROW 50050, 'User not found in dbo.Users (cannot determine CurrentRole).', 1;

    INSERT INTO dbo.RoleRequests
        (Username, CurrentRole, RequestedRole, Reason, Status, DateSubmitted)
    VALUES
        (@Username, @CurrentRole, @RequestedRole, @Reason, 'Pending', GETDATE());
END
GO


CREATE OR ALTER PROCEDURE ListPendingRoleRequests @AdminUser NVARCHAR(50)
AS
BEGIN
    IF dbo.UserRole(@AdminUser) <> 'Admin' THROW 50031, 'Admin only.', 1;
    SELECT RequestID, Username, CurrentRole, RequestedRole, Reason, DateSubmitted, Status
    FROM dbo.RoleRequests WHERE Status = 'Pending' ORDER BY DateSubmitted;
END
GO

CREATE OR ALTER PROCEDURE ResolveRoleRequest
    @AdminUser NVARCHAR(50),
    @RequestID INT,
    @Action NVARCHAR(10),
    @NewClearance INT = NULL
AS
BEGIN
    IF dbo.UserRole(@AdminUser) <> 'Admin' THROW 50032, 'Admin only.', 1;
    DECLARE @Username NVARCHAR(50), @RequestedRole NVARCHAR(20), @CurrentStatus NVARCHAR(20);
    SELECT @Username = Username, @RequestedRole = RequestedRole, @CurrentStatus = Status
    FROM dbo.RoleRequests WHERE RequestID = @RequestID;
    IF @CurrentStatus <> 'Pending' THROW 50033, 'Already resolved.', 1;

    IF @Action = 'Approve'
    BEGIN
        UPDATE dbo.[Users] SET RoleName = @RequestedRole, ClearanceLevel = COALESCE(@NewClearance, ClearanceLevel)
        WHERE Username = @Username;

        UPDATE dbo.RoleRequests SET Status='Approved', DateResolved=GETDATE(), ResolvedBy=@AdminUser WHERE RequestID=@RequestID;
    END
    ELSE IF @Action = 'Deny'
    BEGIN
        UPDATE dbo.RoleRequests SET Status='Denied', DateResolved=GETDATE(), ResolvedBy=@AdminUser WHERE RequestID=@RequestID;
    END
    ELSE THROW 50034, 'Invalid action.', 1;
END
GO

---------------------------------------------------------------
-- TASK 10: Grant EXECUTE Permissions
---------------------------------------------------------------
-- Public
GRANT EXECUTE ON ViewPublicCourses TO [Guest], [Student], [TA], [Instructor], [Admin];

-- Profile
GRANT EXECUTE ON ViewOwnProfile TO [Student], [TA], [Instructor], [Admin];
GRANT EXECUTE ON EditOwnProfile TO [TA], [Instructor], [Admin];

-- Grades
GRANT EXECUTE ON ViewGrades TO [Admin], [Instructor];
GRANT EXECUTE ON EnterOrUpdateGrade TO [Admin], [Instructor];

-- Attendance
GRANT EXECUTE ON RecordAttendance TO [Admin], [Instructor], [TA];
GRANT EXECUTE ON ViewAttendance TO [Admin], [Instructor], [TA], [Student];

-- Admin
GRANT EXECUTE ON CreateUser TO [Admin];
GRANT EXECUTE ON UpdateUserRole TO [Admin];
GRANT EXECUTE ON ListPendingRoleRequests TO [Admin];
GRANT EXECUTE ON ResolveRoleRequest TO [Admin];

-- Inference
GRANT EXECUTE ON AvgGradeByDepartment TO [Admin], [Instructor];

-- Role Requests
GRANT EXECUTE ON SubmitRoleUpgradeRequest TO [Student], [TA];
GO

---------------------------------------------------------------
-- TASK 11: Seed Data (for testing)
---------------------------------------------------------------

-- Users
OPEN SYMMETRIC KEY SRMS_AES_Key
DECRYPTION BY CERTIFICATE SRMS_Cert;

INSERT INTO dbo.[Users] VALUES
('admin1', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'adminpass'), 'Admin', 4),
('inst1',  EncryptByKey(Key_GUID('SRMS_AES_Key'), N'instpass'),  'Instructor', 3),
('ta1',    EncryptByKey(Key_GUID('SRMS_AES_Key'), N'tapass'),    'TA', 3),
('stud1@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'studpass'), 'Student', 2),
('guest1', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'guestpass'), 'Guest', 1);




CLOSE SYMMETRIC KEY SRMS_AES_Key;



-- Students (real StudentID = 1001, encrypted)
OPEN SYMMETRIC KEY SRMS_AES_Key
DECRYPTION BY CERTIFICATE SRMS_Cert;
GO

-- 2. Insert encrypted values
INSERT INTO dbo.Student (
    StudentID_Enc,
    FullName,
    Email,
    PhoneEnc,
    DOB,
    Department,
    ClearanceLevel
)
VALUES (
    EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1001')),
    'Alice Student',
    'stud1@nu.edu',
    EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '555-1234')),
    '2000-01-01',
    'Computer Science',
    2
);
GO

-- 3. (Optional but recommended) Close the key
CLOSE SYMMETRIC KEY SRMS_AES_Key;
GO




OPEN SYMMETRIC KEY SRMS_AES_Key
DECRYPTION BY CERTIFICATE SRMS_Cert;

INSERT INTO dbo.Student
(StudentID_Enc, FullName, Email, PhoneEnc, DOB, Department, ClearanceLevel)
VALUES (
    EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1000')),
    'Zeyad Student',
    'stud2',
    EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '555-5555')),
    '2000-01-01',
    'Computer Science',
    2
);

CLOSE SYMMETRIC KEY SRMS_AES_Key;




-- Course
INSERT INTO dbo.Course VALUES (101, 'Database Security', 'Secure DB design', 'Open to all');
INSERT INTO dbo.Course VALUES (102, 'Advanced Database', 'SQL Server', 'Open to all');

CLOSE SYMMETRIC KEY SRMS_AES_Key;
GO
--------------------------------------------------------------
-- Removing old Data

-- Grades depend on Student & Course
DELETE FROM dbo.Grades;

-- Attendance depends on Student & Course
DELETE FROM dbo.Attendance;

-- Role Requests depend on Users
DELETE FROM dbo.RoleRequests;
GO

DELETE FROM dbo.Student;
DELETE FROM dbo.Course;
GO

DELETE FROM dbo.Users;
GO

SELECT COUNT(*) AS UsersCount FROM dbo.Users;
SELECT COUNT(*) AS StudentsCount FROM dbo.Student;
SELECT COUNT(*) AS CoursesCount FROM dbo.Course;
SELECT COUNT(*) AS GradesCount FROM dbo.Grades;
SELECT COUNT(*) AS AttendanceCount FROM dbo.Attendance;
SELECT COUNT(*) AS RequestsCount FROM dbo.RoleRequests;

-- Inserting New Data
OPEN SYMMETRIC KEY SRMS_AES_Key
DECRYPTION BY CERTIFICATE SRMS_Cert;
GO

INSERT INTO dbo.Users (Username, PasswordEnc, RoleName, ClearanceLevel)
VALUES
-- Admins
('admin1', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'adminpass'), 'Admin', 4),
('admin2', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'admin2pass'), 'Admin', 4),

-- Instructors
('inst1', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'instpass'), 'Instructor', 3),
('inst2@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'inst2pass'), 'Instructor', 3),

-- TAs
('ta1', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'tapass'), 'TA', 3),
('ta2@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'ta2pass'), 'TA', 3),

-- Students
('stud1@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'studpass'), 'Student', 2),
('stud2@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'stud2pass'), 'Student', 2),
('stud3@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'stud3pass'), 'Student', 2),
('stud4@nu.edu', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'stud4pass'), 'Student', 2),
-- Guests
('guest1', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'guestpass'), 'Guest', 1),
('guest2', EncryptByKey(Key_GUID('SRMS_AES_Key'), N'guest2pass'), 'Guest', 1);
GO

INSERT INTO dbo.Student
(StudentID_Enc, FullName, Email, PhoneEnc, DOB, Department, ClearanceLevel)
VALUES
(
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1001')),
 'Alice Student',
 'stud1@nu.edu',
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '01011112222')),
 '2000-01-01',
 'Computer Science',
 2
),
(
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1002')),
 'Mohamed Hassan',
 'stud2@nu.edu',
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '01022223333')),
 '2001-05-15',
 'Computer Science',
 2
),
(
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1003')),
 'Sara Ali',
 'stud3@nu.edu',
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '01033334444')),
 '2002-09-10',
 'Information Systems',
 2
),
(
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1003')),
 'Zizo',
 'stud4@nu.edu',
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '01033334444')),
 '2005-05-05',
 'Computer Science',
 2
);
GO

INSERT INTO dbo.Student
(StudentID_Enc, FullName, Email, PhoneEnc, DOB, Department, ClearanceLevel)
VALUES
(
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '1002')),
 'Mohamed Hassan',
 'stud2@nu.edu',
 EncryptByKey(Key_GUID('SRMS_AES_Key'), CONVERT(VARBINARY(20), '01022223333')),
 '2001-05-15',
 'Computer Science',
 2
);


INSERT INTO dbo.Course
VALUES (101, 'Database Security', 'Secure DB design', 'Open to all');
GO

CLOSE SYMMETRIC KEY SRMS_AES_Key;
GO

EXEC ValidateLogin 'stud1@nu.edu', 'studpass';
EXEC ViewOwnProfile 'stud1@nu.edu';
EXEC ViewPublicCourses 'guest1';

EXEC EnterOrUpdateGrade 'inst1', 'stud1@nu.edu', 101, 90;
EXEC AvgGradeByDepartment 'admin1', 'Computer Science';

-----------------------------------------------------
-- Test
-----------------------------------------------------

-- Valid logins
EXEC ValidateLogin @Username='stud1@nu.edu', @PlainPassword='studpass';
EXEC ValidateLogin @Username='admin1',        @PlainPassword='adminpass';

-- Invalid password -> should throw 50002
EXEC ValidateLogin @Username='stud1@nu.edu', @PlainPassword='wrongpass';

-- Unknown user -> should throw 50002
EXEC ValidateLogin @Username='unknown@nu.edu', @PlainPassword='123';

-- Student views own profile
EXEC ViewOwnProfile @Username='stud1@nu.edu';
EXEC ViewOwnProfile @Username='stud2@nu.edu';

-- Instructor / TA / Admin can view all profiles
EXEC ViewOwnProfile @Username='inst1';
EXEC ViewOwnProfile @Username='ta1';
EXEC ViewOwnProfile @Username='admin1';
-- Problem with the ViewOwnProfile --> Bt3l show ll Students bs hta lw admin

EXEC ViewProfilesByRole 'admin1';       -- works
EXEC ViewProfilesByRole 'inst1';        -- works
EXEC ViewProfilesByRole 'ta1';          -- works
EXEC ViewProfilesByRole 'stud1@nu.edu'; -- works


-- GRADE MODIFICATION TESTS (RBAC + MLS)
-----------------------------------------
-- Student tries to modify grades → should throw 50008
EXEC EnterOrUpdateGrade
    @Username='stud1@nu.edu',
    @StudentEmail='stud1@nu.edu',
    @CourseID=101,
    @GradeValue=90;

-- TA tries to modify grades → should throw 50008
EXEC EnterOrUpdateGrade
    @Username='ta1',
    @StudentEmail='stud1@nu.edu',
    @CourseID=101,
    @GradeValue=90;

-- Instructor modifies grade → should succeed
EXEC EnterOrUpdateGrade
    @Username='inst1',
    @StudentEmail='stud1@nu.edu',
    @CourseID=101,
    @GradeValue=95;

-- Admin modifies grade → should succeed
EXEC EnterOrUpdateGrade
    @Username='admin1',
    @StudentEmail='stud1@nu.edu',
    @CourseID=101,
    @GradeValue=100;

-- GRADE VIEWING (ACCESS CONTROL)
----------------------------------
-- Student tries to view grades → should throw 50011
EXEC ViewGrades
    @Username='stud1@nu.edu',
    @StudentEmail='stud2@nu.edu';

EXEC ViewGrades
    @Username='ta1',
    @StudentEmail='stud2@nu.edu';

-- Instructor/Admin views student grades
EXEC ViewGrades
    @Username='inst1',
    @StudentEmail='stud2@nu.edu';

EXEC ViewGrades
    @Username='admin1',
    @StudentEmail='stud1@nu.edu';

-- ATTENDANCE RECORDING
------------------------
-- TA records attendance (valid student)
EXEC RecordAttendance
    @Username='ta1',
    @StudentEmail='stud2@nu.edu',
    @CourseID=101,
    @Status=1;

-- Instructor records attendance (valid student)
EXEC RecordAttendance
    @Username='insta1',
    @StudentEmail='stud2@nu.edu',
    @CourseID=102,
    @Status=1;

-- TA records attendance for non-existing student → should throw 50025
EXEC RecordAttendance
    @Username='ta1',
    @StudentEmail='fake@nu.edu',
    @CourseID=101,
    @Status=1;

-- Student tries to record attendance → should throw 50013
EXEC RecordAttendance
    @Username='stud1@nu.edu',
    @StudentEmail='stud1@nu.edu',
    @CourseID=101,
    @Status=1;

-- ATTENDANCE VIEWING
------------------------
-- Student views own attendance
EXEC ViewAttendance @Username='stud1@nu.edu';
EXEC ViewAttendance @Username='stud2@nu.edu';

-- Admin views all attendance
EXEC ViewAttendance @Username='admin1';
EXEC ViewAttendance @Username='ta1';
EXEC ViewAttendance @Username='inst1';

-- ADMIN ROLE MANAGEMENT
-------------------------
-- Update non-existing user → no row affected (safe behavior)
EXEC UpdateUserRole
    @AdminUser='admin1',
    @TargetUser='fake@nu.edu',
    @NewRole='Student',
    @NewClearance=2;

-- Admin updates real user role
EXEC UpdateUserRole
    @AdminUser='admin1',
    @TargetUser='stud4@nu.edu',
    @NewRole='TA',
    @NewClearance=3;

-- Verify role update
SELECT Username, RoleName, ClearanceLevel
FROM dbo.Users
WHERE Username='stud4@nu.edu';

-- ROLE REQUEST WORKFLOW (PART B)
EXEC SubmitRoleUpgradeRequest
    @Username='stud1@nu.edu',
    @RequestedRole='TA',
    @Reason='I want to assist';

-- Admin lists pending requests → should succeed
EXEC ListPendingRoleRequests
    @AdminUser='admin1';

EXEC ListPendingRoleRequests
    @AdminUser='inst1';

-- EditOwnProfile
-- Admin/TA edits his own profile (SUCCESS)
EXEC EditOwnProfile
    @Username = 'admin1',
    @NewFullName = 'Ahmed Admin';

EXEC EditOwnProfile
    @Username = 'ta1',
    @NewFullName = 'Zeyad';

-- Student tries to edit profile (FAILs – expected)
EXEC EditOwnProfile
    @Username = 'stud1@nu.edu',
    @NewFullName = 'Hacker Student';



-- RequestID must be read from previous SELECT output
EXEC ResolveRoleRequest
    @AdminUser='admin1',
    @RequestID=1,
    @Action='Approve',
    @NewClearance=3;

SELECT Username, RoleName, ClearanceLevel
FROM dbo.Users
WHERE Username='stud1@nu.edu';

-- Return stud1@nu.edu to StudentRole to Continue testing
UPDATE dbo.Users
SET RoleName = 'Student',
    ClearanceLevel = 2
WHERE Username = 'stud4@nu.edu';
GO

SELECT Username, RoleName, ClearanceLevel
FROM dbo.Users
WHERE Username = 'stud4@nu.edu';

-- Case 1: Department has ≥ 3 students → should SUCCEED
EXEC AvgGradeByDepartment
    @Username='admin1',
    @Department='Computer Science';

-- Instructor assigns grades to all CS students
EXEC EnterOrUpdateGrade 'inst1', 'stud1@nu.edu', 101, 90;
EXEC EnterOrUpdateGrade 'inst1', 'stud2@nu.edu', 101, 85;
EXEC EnterOrUpdateGrade 'inst1', 'stud3@nu.edu', 101, 88;


UPDATE dbo.Student
SET Department = 'Computer Science'
WHERE Email IN ('stud1@nu.edu','stud2@nu.edu','stud3@nu.edu', 'stud4@nu.edu');
EXEC EnterOrUpdateGrade 'inst1', 'stud1@nu.edu', 101, 90;
EXEC EnterOrUpdateGrade 'inst1', 'stud2@nu.edu', 101, 85;
EXEC EnterOrUpdateGrade 'inst1', 'stud3@nu.edu', 101, 88;
EXEC EnterOrUpdateGrade 'inst1', 'stud4@nu.edu', 101, 98;

UPDATE dbo.Student
SET Department = 'SoloDept'
WHERE Email = 'stud1@nu.edu';

EXEC AvgGradeByDepartment 'admin1', 'SoloDept';

-- Now inference should succeed
EXEC AvgGradeByDepartment
    @Username='admin1',
    @Department='Computer Science';

UPDATE dbo.Student
SET Department = 'Information Systems'
WHERE Email = 'stud3@nu.edu';
GO

SELECT Email, Department
FROM dbo.Student
ORDER BY Email;

EXEC EnterOrUpdateGrade 'inst1', 'stud1@nu.edu', 101, 90;
EXEC EnterOrUpdateGrade 'inst1', 'stud2@nu.edu', 101, 85;
EXEC EnterOrUpdateGrade 'inst1', 'stud4@nu.edu', 101, 98;

EXEC AvgGradeByDepartment 'admin1', 'Computer Science';

EXEC AvgGradeByDepartment 'admin1', 'Information Systems';

---------------------------------------------------------------
-- TASK 12: DB Users + Roles
---------------------------------------------------------------
CREATE USER [admin1] WITHOUT LOGIN;
CREATE USER [inst1] WITHOUT LOGIN;
CREATE USER [ta1] WITHOUT LOGIN;
CREATE USER [stud1@nu.edu] WITHOUT LOGIN;
CREATE USER [guest1] WITHOUT LOGIN;
GO

ALTER ROLE [Admin] ADD MEMBER [admin1];
ALTER ROLE [Instructor] ADD MEMBER [inst1];
ALTER ROLE [TA] ADD MEMBER [ta1];
ALTER ROLE [Student] ADD MEMBER [stud1@nu.edu];
ALTER ROLE [GuestUser] ADD MEMBER [guest1]; 
GO




SELECT * FROM Student;

---------------------------------testing---------------------------------------
----Login works



EXEC ValidateLogin @Username = 'stud1@nu.edu', @PlainPassword = 'studpass';
 

EXEC ValidateLogin @Username = 'admin1', @PlainPassword = 'adminpass';

 ----Student views own profile
EXEC ViewOwnProfile @Username = 'stud1@nu.edu';

---Student tries to view grades will fail
EXEC ViewGrades @Username = 'stud1@nu.edu', @StudentEmail = 'stud1@nu.edu';

---- Instructor enters a grade
EXEC EnterOrUpdateGrade 
    @Username = 'inst1', 
    @StudentEmail = 'stud1@nu.edu', 
    @CourseID = 101, 
    @GradeValue = 92.5;

----Instructor views that grade
EXEC ViewGrades @Username = 'inst1', @StudentEmail = 'stud1@nu.edu';
 
----Student views own attendance
EXEC ViewAttendance @Username = 'stud1@nu.edu';

-----TA records attendance
EXEC RecordAttendance 
    @Username = 'ta1', 
    @StudentEmail = 'stud1@nu.edu', 
    @CourseID = 101, 
    @Status = 1;

EXEC RecordAttendance 
    @Username = 'ta1', 
    @StudentEmail = 'Sadek', 
    @CourseID = 101, 
    @Status = 1;


    ----Guest views public courses  

    EXEC ViewPublicCourses @Username = 'guest1';

    -----Student submits role upgrade request
    EXEC SubmitRoleUpgradeRequest 
    @Username = 'stud1@nu.edu', 
    @RequestedRole = 'TA', 
    @Reason = 'I am now a teaching assistant.';


    -----Admin sees pending request
    EXEC ListPendingRoleRequests @AdminUser = 'admin1';

    -- First, get the RequestID (look at the output from step 10 — probably 1)
-- Then run:
EXEC ResolveRoleRequest 
    @AdminUser = 'admin1', 
    @RequestID = 3, 
    @Action = 'Approve', 
    @NewClearance = 3;

 ----Check that student is now a TA
SELECT Username, RoleName FROM dbo.Users WHERE Username = 'stud1@nu.edu';
-- Should show: stud1@nu.edu | TA


---------------------------------------------
-- Put student in a unique department
UPDATE dbo.Student SET Department = 'SoloDept' WHERE Email = 'stud1@nu.edu';
--  get average grade only 1 student
EXEC AvgGradeByDepartment @Username = 'admin1', @Department = 'SoloDept';
/*-------------------------------------------------------------------*/



