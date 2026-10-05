-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 6: University Event Seat Booking
-- Student number: STUDENTNUMBER
-- (Run in pgAdmin Query Tool; RAISE NOTICE output appears in the Messages tab)

DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;

------------------------------------------------------------
-- 1. Create tables and add at least three events
------------------------------------------------------------
CREATE TABLE events (
    event_id        SERIAL PRIMARY KEY,
    event_name      VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id      SERIAL PRIMARY KEY,
    event_id        INT NOT NULL REFERENCES events(event_id),
    student_number  VARCHAR(20) NOT NULL,
    number_of_seats INT NOT NULL CHECK (number_of_seats > 0),
    status          VARCHAR(20) NOT NULL DEFAULT 'BOOKED'
);

INSERT INTO events (event_name, available_seats) VALUES
    ('Freshers Welcome Party', 150),
    ('Tech Symposium', 8),
    ('Career Fair', 0),
    ('Engineering Expo', 40);

SELECT * FROM events ORDER BY event_id;

------------------------------------------------------------
-- 2. IF / ELSIF / ELSE: seat availability of each event
------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT event_name, available_seats FROM events ORDER BY event_id LOOP
        IF r.available_seats = 0 THEN
            RAISE NOTICE '%: FULL', r.event_name;
        ELSIF r.available_seats <= 10 THEN
            RAISE NOTICE '%: NEARLY FULL (% seats left)', r.event_name, r.available_seats;
        ELSE
            RAISE NOTICE '%: plenty of seats (%)', r.event_name, r.available_seats;
        END IF;
    END LOOP;
END $$;

------------------------------------------------------------
-- 3. WHILE loop (booking reminder days) and numeric FOR loop (entrance checks)
------------------------------------------------------------
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Booking reminder day %', d;
        d := d + 1;
    END LOOP;

    FOR c IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number %', c;
    END LOOP;
END $$;

------------------------------------------------------------
-- 4. book_seats procedure
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE book_seats(p_event_id INT, p_student VARCHAR, p_seats INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_seats IS NULL OR p_seats <= 0 THEN
        RAISE EXCEPTION 'Invalid number of seats: % (must be greater than zero)', p_seats;
    END IF;

    SELECT available_seats INTO v_available
    FROM events
    WHERE event_id = p_event_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event % does not exist', p_event_id;
    END IF;

    IF v_available < p_seats THEN
        RAISE NOTICE 'Booking REJECTED for student %: requested %, only % seats left',
                     p_student, p_seats, v_available;
        RETURN;
    END IF;

    UPDATE events
    SET available_seats = available_seats - p_seats
    WHERE event_id = p_event_id;

    INSERT INTO bookings (event_id, student_number, number_of_seats, status)
    VALUES (p_event_id, p_student, p_seats, 'BOOKED');

    RAISE NOTICE 'Booking recorded: student % booked % seat(s) for event %',
                 p_student, p_seats, p_event_id;
END $$;

------------------------------------------------------------
-- 5. Two valid bookings and one exceeding the remaining seats
------------------------------------------------------------
CALL book_seats(1, '2024001', 4);    -- valid
CALL book_seats(2, '2024002', 5);    -- valid (leaves 3 seats)
CALL book_seats(2, '2024003', 10);   -- exceeds remaining seats

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

------------------------------------------------------------
-- 6. cancel_booking procedure (second call must not release seats again)
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id INT;
    v_seats    INT;
    v_status   VARCHAR(20);
BEGIN
    SELECT event_id, number_of_seats, status
    INTO v_event_id, v_seats, v_status
    FROM bookings
    WHERE booking_id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Booking % does not exist', p_booking_id;
        RETURN;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % is already cancelled; no seats released', p_booking_id;
        RETURN;
    END IF;

    UPDATE events
    SET available_seats = available_seats + v_seats
    WHERE event_id = v_event_id;

    UPDATE bookings
    SET status = 'CANCELLED'
    WHERE booking_id = p_booking_id;

    RAISE NOTICE 'Booking % cancelled; % seat(s) released', p_booking_id, v_seats;
END $$;

CALL cancel_booking(2);   -- first call releases seats
CALL cancel_booking(2);   -- second call does nothing

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

------------------------------------------------------------
-- 7. Explicit cursor: full or nearly full events (10 seats or fewer)
------------------------------------------------------------
DO $$
DECLARE
    cur_events CURSOR FOR
        SELECT event_name, available_seats
        FROM events
        WHERE available_seats <= 10
        ORDER BY available_seats, event_name;
    v_name  events.event_name%TYPE;
    v_seats events.available_seats%TYPE;
BEGIN
    OPEN cur_events;
    LOOP
        FETCH cur_events INTO v_name, v_seats;
        EXIT WHEN NOT FOUND;
        IF v_seats = 0 THEN
            RAISE NOTICE 'Event "%" is FULL', v_name;
        ELSE
            RAISE NOTICE 'Event "%" is nearly full (% seats left)', v_name, v_seats;
        END IF;
    END LOOP;
    CLOSE cur_events;
END $$;

------------------------------------------------------------
-- 8. Book zero seats; handle with EXCEPTION
------------------------------------------------------------
DO $$
BEGIN
    CALL book_seats(1, '2024004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

------------------------------------------------------------
-- 9. Final state of both tables
------------------------------------------------------------
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;
