INSERT INTO characters (name, age) VALUES
  ('Ai Hoshino', 20),
  ('Aquamarine Hoshino', 17),
  ('Ruby Hoshino', 15),
  ('Kana Arima', 18),
  ('Akane Kurokawa', 19);

INSERT INTO events (character_id, type, date) VALUES
  (1, 'Concert', '2025-04-12'),
  (1, 'Interview', '2025-05-01'),
  (2, 'Concert', '2025-04-15'),
  (3, 'Concert', '2025-04-20'),
  (4, 'Interview', '2025-05-03'),
  (5, 'Incident', '2025-04-25');

-- ===== TEST TRIGGERS ===== --


-- Test 1: Attempt to add incident for underage character (should fail)

DO $$
BEGIN
  RAISE NOTICE 'TEST 1: Attempting invalid incident for Ruby (age 15)...';
  INSERT INTO events (character_id, type, date) 
  VALUES (3, 'Incident', '2025-05-02');
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Trigger blocked underage incident: %', SQLERRM;
END $$;


-- Test 2: Update character to trigger timestamp

DO $$
BEGIN
  RAISE NOTICE 'TEST 2: Updating Ai Hoshino''s age...';
  UPDATE characters SET age = 21 WHERE name = 'Ai Hoshino';
  RAISE NOTICE 'Timestamp updated: %', 
    (SELECT last_updated FROM characters WHERE name = 'Ai Hoshino');
END $$;


-- Test 3: Verify event counter

DO $$
DECLARE
    count_info TEXT;
BEGIN
    RAISE NOTICE 'TEST 3: Current event counts:';
    FOR count_info IN 
        SELECT name || ': ' || event_count || ' events' 
        FROM characters ORDER BY id
    LOOP
        RAISE NOTICE '%', count_info;
    END LOOP;
END $$;


-- Test 4: Delete event to test counter decrement

DO $$
BEGIN
  RAISE NOTICE 'TEST 4: Deleting an event...';
  DELETE FROM events WHERE character_id = 1 AND type = 'Interview';
  RAISE NOTICE '✅ New count for Ai Hoshino: %', 
    (SELECT event_count FROM characters WHERE id = 1);
END $$;


-- Final validation

SELECT c.name, c.age, c.event_count, e.type, e.date 
FROM characters c 
LEFT JOIN events e ON c.id = e.character_id
ORDER BY c.id, e.date;
