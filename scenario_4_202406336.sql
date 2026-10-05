-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Student number: STUDENTNUMBER
-- (Run in pgAdmin Query Tool; RAISE NOTICE output appears in the Messages tab)

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

------------------------------------------------------------
-- 1. Create tables and add at least three medicines
------------------------------------------------------------
CREATE TABLE medicines (
    medicine_id    SERIAL PRIMARY KEY,
    medicine_name  VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id      SERIAL PRIMARY KEY,
    medicine_id    INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    status         VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
    ('Paracetamol 500mg', 100),
    ('Amoxicillin 250mg', 15),
    ('Artemether-Lumefantrine', 0),
    ('Oral Rehydration Salts', 40);

SELECT * FROM medicines ORDER BY medicine_id;

------------------------------------------------------------
-- 2. IF / ELSIF / ELSE: stock level of each medicine
------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
        IF r.stock_quantity = 0 THEN
            RAISE NOTICE '%: OUT OF STOCK', r.medicine_name;
        ELSIF r.stock_quantity <= 20 THEN
            RAISE NOTICE '%: LOW on stock (% units)', r.medicine_name, r.stock_quantity;
        ELSE
            RAISE NOTICE '%: sufficiently stocked (% units)', r.medicine_name, r.stock_quantity;
        END IF;
    END LOOP;
END $$;

------------------------------------------------------------
-- 3. WHILE loop (stock review days) and numeric FOR loop (shelf inspections)
------------------------------------------------------------
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Stock review day %', d;
        d := d + 1;
    END LOOP;

    FOR s IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number %', s;
    END LOOP;
END $$;

------------------------------------------------------------
-- 4. dispense_medicine procedure
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE dispense_medicine(p_medicine_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: % (must be greater than zero)', p_qty;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine % does not exist', p_medicine_id;
    END IF;

    IF v_stock < p_qty THEN
        RAISE NOTICE 'Dispensing REJECTED for student %: requested %, only % in stock',
                     p_student, p_qty, v_stock;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_qty
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
    VALUES (p_medicine_id, p_student, p_qty, 'DISPENSED');

    RAISE NOTICE 'Dispensed % unit(s) of medicine % to student %',
                 p_qty, p_medicine_id, p_student;
END $$;

------------------------------------------------------------
-- 5. Two valid quantities and one exceeding stock
------------------------------------------------------------
CALL dispense_medicine(1, '2024001', 20);   -- valid
CALL dispense_medicine(2, '2024002', 10);   -- valid (leaves 5)
CALL dispense_medicine(2, '2024003', 50);   -- exceeds stock

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

------------------------------------------------------------
-- 6. reverse_dispensing procedure (stock restored only once)
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INT;
    v_qty         INT;
    v_status      VARCHAR(20);
BEGIN
    SELECT medicine_id, quantity, status
    INTO v_medicine_id, v_qty, v_status
    FROM dispensing_records
    WHERE record_id = p_record_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Dispensing record % does not exist', p_record_id;
        RETURN;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already reversed; stock not restored again', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity + v_qty
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET status = 'REVERSED'
    WHERE record_id = p_record_id;

    RAISE NOTICE 'Record % reversed; % unit(s) restored to stock', p_record_id, v_qty;
END $$;

CALL reverse_dispensing(2);   -- first call restores stock
CALL reverse_dispensing(2);   -- second call does nothing

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

------------------------------------------------------------
-- 7. Explicit cursor: medicines below a low-stock threshold
------------------------------------------------------------
DO $$
DECLARE
    v_threshold CONSTANT INT := 20;
    cur_low CURSOR (p_limit INT) FOR
        SELECT medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < p_limit
        ORDER BY stock_quantity, medicine_name;
    v_name  medicines.medicine_name%TYPE;
    v_stock medicines.stock_quantity%TYPE;
BEGIN
    OPEN cur_low(v_threshold);
    LOOP
        FETCH cur_low INTO v_name, v_stock;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below threshold of %: % (% units)', v_threshold, v_name, v_stock;
    END LOOP;
    CLOSE cur_low;
END $$;

------------------------------------------------------------
-- 8. Negative dispensing quantity; handle with EXCEPTION
------------------------------------------------------------
DO $$
BEGIN
    CALL dispense_medicine(1, '2024004', -5);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

------------------------------------------------------------
-- 9. Final state of both tables
------------------------------------------------------------
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
