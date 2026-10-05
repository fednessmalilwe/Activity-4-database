-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation
-- Student number: STUDENTNUMBER
-- (Run in pgAdmin Query Tool; RAISE NOTICE output appears in the Messages tab)

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

------------------------------------------------------------
-- 1. Create tables and add at least three rooms
------------------------------------------------------------
CREATE TABLE hostel_rooms (
    room_id          SERIAL PRIMARY KEY,
    room_name        VARCHAR(20) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id  SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    room_id        INT NOT NULL REFERENCES hostel_rooms(room_id),
    status         VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO hostel_rooms (room_name, available_spaces) VALUES
    ('A101', 4),
    ('B102', 1),
    ('C201', 0),
    ('D301', 3);

SELECT * FROM hostel_rooms ORDER BY room_id;

------------------------------------------------------------
-- 2. IF / ELSIF / ELSE: room occupancy report
------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT room_name, available_spaces FROM hostel_rooms ORDER BY room_id LOOP
        IF r.available_spaces = 0 THEN
            RAISE NOTICE 'Room %: FULL', r.room_name;
        ELSIF r.available_spaces = 1 THEN
            RAISE NOTICE 'Room %: only ONE space left', r.room_name;
        ELSE
            RAISE NOTICE 'Room %: several spaces available (%)', r.room_name, r.available_spaces;
        END IF;
    END LOOP;
END $$;

------------------------------------------------------------
-- 3. WHILE loop (inspection days) and numeric FOR loop (room checks)
------------------------------------------------------------
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', d;
        d := d + 1;
    END LOOP;

    FOR chk IN 1..3 LOOP
        RAISE NOTICE 'Room check number %', chk;
    END LOOP;
END $$;

------------------------------------------------------------
-- 4. allocate_room procedure
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE allocate_room(p_student VARCHAR, p_room_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student IS NULL OR TRIM(p_student) = '' THEN
        RAISE EXCEPTION 'Invalid input: student number cannot be blank';
    END IF;

    SELECT available_spaces INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room % does not exist', p_room_id;
    END IF;

    IF v_spaces < 1 THEN
        RAISE NOTICE 'Allocation REJECTED for student %: room % is full', p_student, p_room_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_spaces = available_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations (student_number, room_id, status)
    VALUES (TRIM(p_student), p_room_id, 'ACTIVE');

    RAISE NOTICE 'Student % allocated to room %', p_student, p_room_id;
END $$;

------------------------------------------------------------
-- 5. Two valid allocations and one to a full room
------------------------------------------------------------
CALL allocate_room('2024001', 1);   -- valid
CALL allocate_room('2024002', 2);   -- valid (room B102 becomes full)
CALL allocate_room('2024003', 3);   -- room C201 is full

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

------------------------------------------------------------
-- 6. check_out procedure (second call must not free another space)
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
    v_status  VARCHAR(20);
BEGIN
    SELECT room_id, status INTO v_room_id, v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Allocation % does not exist', p_allocation_id;
        RETURN;
    END IF;

    IF v_status = 'COMPLETE' THEN
        RAISE NOTICE 'Allocation % is already checked out; no space released', p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_spaces = available_spaces + 1
    WHERE room_id = v_room_id;

    UPDATE allocations
    SET status = 'COMPLETE'
    WHERE allocation_id = p_allocation_id;

    RAISE NOTICE 'Allocation % checked out; one space released in room %',
                 p_allocation_id, v_room_id;
END $$;

CALL check_out(2);   -- first call frees a space in B102
CALL check_out(2);   -- second call does nothing

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

------------------------------------------------------------
-- 7. Explicit cursor: full or nearly full rooms (1 space or fewer)
------------------------------------------------------------
DO $$
DECLARE
    cur_rooms CURSOR FOR
        SELECT room_name, available_spaces
        FROM hostel_rooms
        WHERE available_spaces <= 1
        ORDER BY room_name;
    v_name   hostel_rooms.room_name%TYPE;
    v_spaces hostel_rooms.available_spaces%TYPE;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO v_name, v_spaces;
        EXIT WHEN NOT FOUND;
        IF v_spaces = 0 THEN
            RAISE NOTICE 'Room % is FULL', v_name;
        ELSE
            RAISE NOTICE 'Room % is nearly full (% space left)', v_name, v_spaces;
        END IF;
    END LOOP;
    CLOSE cur_rooms;
END $$;

------------------------------------------------------------
-- 8. Blank student number; handle with EXCEPTION
------------------------------------------------------------
DO $$
BEGIN
    CALL allocate_room('   ', 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

------------------------------------------------------------
-- 9. Final state of both tables
------------------------------------------------------------
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
