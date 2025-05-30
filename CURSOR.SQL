-- ====================================================
-- Завдання 3. Транзакція з двома операціями та умовою, що призводить до ROLLBACK
-- ====================================================
BEGIN TRAN;

-- 1. Оновлення імені викладача
UPDATE Teachers
SET full_name = N'Іван Іванов'
WHERE id = 1;

-- 2. Оновлення номеру аудиторії з неіснуючим id (щоб викликати ROLLBACK)
UPDATE Auditoriums
SET room_number = '999'
WHERE id = -1;

-- Перевірка умови - якщо аудиторії з id = -1 не існує, ROLLBACK
IF (SELECT COUNT(*) FROM Auditoriums WHERE id = -1) = 0
    ROLLBACK;
ELSE
    COMMIT;


-- ====================================================
-- Завдання 4. Використання @@ERROR для керування транзакцією
-- ====================================================
BEGIN TRAN;

-- 1. Оновлення імені викладача
UPDATE Teachers
SET full_name = 'Shirokov E.E.'
WHERE id = 2;
-- Перевірка помилки після оновлення викладача
IF @@ERROR <> 0
BEGIN
    ROLLBACK;
    PRINT N'Помилка при оновленні викладача';
    RETURN;
END

-- 2. Оновлення номеру аудиторії з неіснуючим id (щоб викликати помилку)
UPDATE Auditoriums
SET room_number = '888'
WHERE id = -1;
-- Перевірка помилки після оновлення аудиторії
IF @@ERROR <> 0
BEGIN
    ROLLBACK;
    PRINT N'Помилка при оновленні аудиторії';
    RETURN;
END

COMMIT;



-- ====================================================
-- Завдання 5. Транзакція з обробкою помилок TRY...CATCH
-- ====================================================

BEGIN TRAN;
BEGIN TRY
    -- Перша операція: валідна
    UPDATE Groups
    SET headman = 'New Headman'
    WHERE id = 1;

    -- Друга операція: помилка (порушення CHECK)
    UPDATE Groups
    SET course = -5
    WHERE id = 1;

    COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    SELECT ERROR_MESSAGE() AS ErrorMessage;
END CATCH;





-- ====================================================
-- Завдання 6. Транзакція масового вставлення 10'000+ рядків
-- ====================================================

BEGIN TRAN;
BEGIN TRY
    DECLARE @i INT = 1;

    WHILE @i <= 10000
    BEGIN
        INSERT INTO Subjects (name)
        VALUES (CONCAT('Subject ', @i));

        SET @i += 1;
    END

    COMMIT;
END TRY
BEGIN CATCH
    ROLLBACK;
    SELECT ERROR_MESSAGE() AS ErrorMessage;
END CATCH;



-- ====================================================
-- Завдання 7. Транзакція з модифікацією процедури без GO
-- Додаємо PRINT-мітки на початку й кінці
-- ====================================================

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.usp_TimestampDemo', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_TimestampDemo;

EXECUTE(N'
    CREATE PROCEDURE dbo.usp_TimestampDemo
    AS
    BEGIN
        SET NOCOUNT ON;

        -- Фіксуємо початок
        DECLARE @ts_start DATETIME = GETDATE();
        PRINT ''usp_TimestampDemo START: '' + CONVERT(VARCHAR(23), @ts_start, 121);

        SELECT COUNT(*) AS TeacherCount FROM Teachers;

        DECLARE @ts_end DATETIME = GETDATE();
        PRINT ''usp_TimestampDemo END  : '' + CONVERT(VARCHAR(23), @ts_end, 121);
    END
');


EXEC dbo.usp_TimestampDemo;


IF @@ERROR <> 0
    ROLLBACK;
ELSE
    COMMIT;


-- ====================================================
-- Завдання 8
-- ====================================================

-- Включення статистики часу виконання
SET STATISTICS TIME ON;

SELECT 
    s.id,
    s.day_of_week,
    s.pair_number,
    t.full_name AS teacher,
    g.group_number,
    sub.name AS subject,
    a.room_number,
    a.building
FROM master.dbo.Schedule s
JOIN master.dbo.Teachers t ON s.teacher_id = t.id
JOIN master.dbo.Groups g ON s.group_id = g.id
JOIN master.dbo.Subjects sub ON s.subject_id = sub.id
JOIN master.dbo.Auditoriums a ON s.auditorium_id = a.id
WHERE s.day_of_week = 'Monday'
ORDER BY s.pair_number ASC, t.full_name;

SET STATISTICS TIME OFF;



-- Відключення індексів
ALTER INDEX IX_Auditoriums_Type ON master.dbo.Auditoriums DISABLE;
ALTER INDEX IX_Auditoriums_Lectures ON master.dbo.Auditoriums DISABLE;
ALTER INDEX IX_Auditoriums_Lectures_Filtered ON master.dbo.Auditoriums DISABLE;
ALTER INDEX IX_Groups_Course ON master.dbo.Groups DISABLE;
ALTER INDEX IX_Groups_GroupNumber ON master.dbo.Groups DISABLE;
ALTER INDEX IX_Schedule_Subject_Include ON master.dbo.Schedule DISABLE;
ALTER INDEX IX_Schedule_TeacherId ON master.dbo.Schedule DISABLE;
ALTER INDEX UQ__Subjects__72E12F1B53DE6C4D ON master.dbo.Subjects DISABLE;
ALTER INDEX IX_Teachers_Degree ON master.dbo.Teachers DISABLE;



-- Відновлення індексів
ALTER INDEX IX_Auditoriums_Type ON master.dbo.Auditoriums REBUILD;
ALTER INDEX IX_Auditoriums_Lectures ON master.dbo.Auditoriums REBUILD;
ALTER INDEX IX_Auditoriums_Lectures_Filtered ON master.dbo.Auditoriums REBUILD;
ALTER INDEX IX_Groups_Course ON master.dbo.Groups REBUILD;
ALTER INDEX IX_Groups_GroupNumber ON master.dbo.Groups REBUILD;
ALTER INDEX IX_Schedule_Subject_Include ON master.dbo.Schedule REBUILD;
ALTER INDEX IX_Schedule_TeacherId ON master.dbo.Schedule REBUILD;
ALTER INDEX UQ__Subjects__72E12F1B53DE6C4D ON master.dbo.Subjects REBUILD;
ALTER INDEX IX_Teachers_Degree ON master.dbo.Teachers REBUILD;




-- Курсор 1: Вивід записів за понеділком у циклі

DECLARE @StartTime datetime2 = SYSDATETIME();

DECLARE @id int, @day_of_week varchar(15), @pair_number int, @teacher varchar(100);

DECLARE schedule_cursor CURSOR FOR
SELECT s.id, s.day_of_week, s.pair_number, t.full_name
FROM master.dbo.Schedule s
JOIN master.dbo.Teachers t ON s.teacher_id = t.id
WHERE s.day_of_week = 'Monday'
ORDER BY s.pair_number;

OPEN schedule_cursor;
FETCH NEXT FROM schedule_cursor INTO @id, @day_of_week, @pair_number, @teacher;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT CONCAT('ID: ', @id, ', Day: ', @day_of_week, ', Pair: ', @pair_number, ', Teacher: ', @teacher);
    FETCH NEXT FROM schedule_cursor INTO @id, @day_of_week, @pair_number, @teacher;
END

CLOSE schedule_cursor;
DEALLOCATE schedule_cursor;

DECLARE @EndTime datetime2 = SYSDATETIME();
PRINT '3. Cursor1 execution time (ms): ' + CONVERT(varchar, DATEDIFF(ms, @StartTime, @EndTime));



-- Курсор 2: Запис у тимчасову таблицю, потім вибірка

DECLARE @StartTime datetime2 = SYSDATETIME();

IF OBJECT_ID('tempdb..#TempSchedule') IS NOT NULL DROP TABLE #TempSchedule;

CREATE TABLE #TempSchedule (
    id int,
    day_of_week varchar(15),
    pair_number int,
    teacher varchar(100)
);

DECLARE @id int, @day_of_week varchar(15), @pair_number int, @teacher varchar(100);

DECLARE schedule_cursor CURSOR FOR
SELECT s.id, s.day_of_week, s.pair_number, t.full_name
FROM master.dbo.Schedule s
JOIN master.dbo.Teachers t ON s.teacher_id = t.id
WHERE s.day_of_week = 'Monday'
ORDER BY s.pair_number;

OPEN schedule_cursor;
FETCH NEXT FROM schedule_cursor INTO @id, @day_of_week, @pair_number, @teacher;

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #TempSchedule VALUES (@id, @day_of_week, @pair_number, @teacher);
    FETCH NEXT FROM schedule_cursor INTO @id, @day_of_week, @pair_number, @teacher;
END

CLOSE schedule_cursor;
DEALLOCATE schedule_cursor;

SELECT * FROM #TempSchedule ORDER BY pair_number;

DECLARE @EndTime datetime2 = SYSDATETIME();
PRINT '4. Cursor2 with temp table execution time (ms): ' + CONVERT(varchar, DATEDIFF(ms, @StartTime, @EndTime));



-- Курсор 2 з підрахунком кількості пар

DECLARE @StartTime datetime2 = SYSDATETIME();

DECLARE @count int;
SELECT @count = COUNT(*) FROM #TempSchedule;

PRINT 'Total pairs on Monday: ' + CONVERT(varchar, @count);

DECLARE @EndTime datetime2 = SYSDATETIME();
PRINT '5. Cursor2 with counting execution time (ms): ' + CONVERT(varchar, DATEDIFF(ms, @StartTime, @EndTime));


-- ====================================================
-- Завдання 9. Додати результат запиту (7) у другий рядок зведеної таблиці
-- ====================================================

CREATE INDEX IX_Teachers_Id ON Teachers(id);
CREATE INDEX IX_Schedule_DayOfWeek_PairNumber ON master.dbo.Schedule(day_of_week, pair_number);



WITH BaseData AS (
    SELECT 
        s.id,
        s.day_of_week,
        s.pair_number,
        t.full_name AS teacher,
        g.group_number,
        sub.name AS subject,
        a.room_number,
        a.building,
        ROW_NUMBER() OVER (ORDER BY s.pair_number, t.full_name) AS rn
    FROM master.dbo.Schedule s
    JOIN master.dbo.Teachers t ON s.teacher_id = t.id
    JOIN master.dbo.Groups g ON s.group_id = g.id
    JOIN master.dbo.Subjects sub ON s.subject_id = sub.id
    JOIN master.dbo.Auditoriums a ON s.auditorium_id = a.id
    WHERE s.day_of_week = 'Monday'
)
, TeacherCountRow AS (
    SELECT
        NULL AS id,
        NULL AS day_of_week,
        NULL AS pair_number,
        'Total Teachers:' AS teacher,
        NULL AS group_number,
        CAST(COUNT(*) AS varchar) AS subject,
        NULL AS room_number,
        NULL AS building,
        2 AS rn
    FROM master.dbo.Teachers
)
SELECT * FROM BaseData WHERE rn = 1 
UNION ALL
SELECT * FROM TeacherCountRow
UNION ALL
SELECT * FROM BaseData WHERE rn > 1 
ORDER BY rn;


-- ====================================================
-- Завдання 11. 
-- ====================================================

DECLARE @StartTime datetime2 = SYSDATETIME();

IF OBJECT_ID('tempdb..#SummarySchedule') IS NOT NULL DROP TABLE #SummarySchedule;

CREATE TABLE #SummarySchedule (
    day_of_week varchar(15),
    pair_number int,
    teacher varchar(100),
    group_number varchar(50),
    subject varchar(100),
    room_number varchar(10),
    building varchar(50),
    row_order int
);

DECLARE 
    @id int,
    @day_of_week varchar(15),
    @pair_number int,
    @teacher varchar(100),
    @group_number varchar(50),
    @subject varchar(100),
    @room_number varchar(10),
    @building varchar(50),
    @row_order int = 1;

DECLARE schedule_cursor CURSOR FOR
SELECT 
    s.id,
    s.day_of_week,
    s.pair_number,
    t.full_name,
    g.group_number,
    sub.name,
    a.room_number,
    a.building
FROM master.dbo.Schedule s
JOIN master.dbo.Teachers t ON s.teacher_id = t.id
JOIN master.dbo.Groups g ON s.group_id = g.id
JOIN master.dbo.Subjects sub ON s.subject_id = sub.id
JOIN master.dbo.Auditoriums a ON s.auditorium_id = a.id
WHERE s.day_of_week = 'Monday'
ORDER BY s.pair_number, t.full_name;

OPEN schedule_cursor;

FETCH NEXT FROM schedule_cursor INTO @id, @day_of_week, @pair_number, @teacher, @group_number, @subject, @room_number, @building;

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #SummarySchedule(day_of_week, pair_number, teacher, group_number, subject, room_number, building, row_order)
    VALUES (@day_of_week, @pair_number, @teacher, @group_number, @subject, @room_number, @building, @row_order);

    SET @row_order += 1;
    FETCH NEXT FROM schedule_cursor INTO @id, @day_of_week, @pair_number, @teacher, @group_number, @subject, @room_number, @building;
END

DECLARE @teacherCount1 int;
SELECT @teacherCount1 = COUNT(*) FROM master.dbo.Teachers;

INSERT INTO #SummarySchedule(day_of_week, pair_number, teacher, group_number, subject, room_number, building, row_order)
VALUES (NULL, NULL, CONCAT('Total Teachers: ', @teacherCount1), NULL, NULL, NULL, NULL, 3);
DECLARE @teacherCount2 int;
SELECT @teacherCount2 = COUNT(*) FROM master.dbo.Teachers;
INSERT INTO #SummarySchedule(day_of_week, pair_number, teacher, group_number, subject, room_number, building, row_order)
VALUES (NULL, NULL, CONCAT('Total Teachers: ', @teacherCount2), NULL, NULL, NULL, NULL, 4);
INSERT INTO #SummarySchedule(day_of_week, pair_number, teacher, group_number, subject, room_number, building, row_order)
VALUES (NULL, NULL, CONCAT('Total Teachers: ', @teacherCount2), NULL, NULL, NULL, NULL, 5);
CLOSE schedule_cursor;
DEALLOCATE schedule_cursor;

SELECT day_of_week, pair_number, teacher, group_number, subject, room_number, building
FROM #SummarySchedule
ORDER BY row_order;

DECLARE @EndTime datetime2 = SYSDATETIME();
PRINT 'Execution time (ms): ' + CONVERT(varchar, DATEDIFF(ms, @StartTime, @EndTime));



