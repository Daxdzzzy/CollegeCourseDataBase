CREATE TABLE characters (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  age INT CHECK (age >= 0),
  last_updated TIMESTAMP,
  event_count INT DEFAULT 0
);

CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  character_id INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  type VARCHAR(20) CHECK (type IN ('Concert', 'Incident', 'Interview')),
  date DATE NOT NULL
);

-- Trigger 1: Auto-update timestamp

CREATE OR REPLACE FUNCTION fn_audit_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_audit_timestamp
BEFORE UPDATE ON characters
FOR EACH ROW EXECUTE FUNCTION fn_audit_timestamp();

-- Trigger 2: Prevent underage incidents

CREATE OR REPLACE FUNCTION fn_block_underage_incidents()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.type = 'Incident' AND (
    SELECT age FROM characters WHERE id = NEW.character_id
  ) < 16 THEN
    RAISE EXCEPTION 'Characters under 16 cannot have incidents!';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_block_underage_incidents
BEFORE INSERT OR UPDATE ON events
FOR EACH ROW EXECUTE FUNCTION fn_block_underage_incidents();

-- Trigger 3: Automatic event counter

CREATE OR REPLACE FUNCTION fn_sync_event_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE characters SET event_count = event_count + 1 
    WHERE id = NEW.character_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE characters SET event_count = event_count - 1 
    WHERE id = OLD.character_id;
  ELSIF (TG_OP = 'UPDATE' AND OLD.character_id <> NEW.character_id) THEN
    UPDATE characters SET event_count = event_count - 1 
    WHERE id = OLD.character_id;
    UPDATE characters SET event_count = event_count + 1 
    WHERE id = NEW.character_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_sync_event_count
AFTER INSERT OR DELETE OR UPDATE ON events
FOR EACH ROW EXECUTE FUNCTION fn_sync_event_count();

-- Optimize performance with index

CREATE INDEX idx_events_character ON events(character_id);
