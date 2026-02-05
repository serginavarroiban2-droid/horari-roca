-- ========================================
-- Taula: worker_calendars
-- Emmagatzema la configuració de Google Calendar per cada treballador
-- ========================================

CREATE TABLE IF NOT EXISTS worker_calendars (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  worker_name TEXT NOT NULL,
  google_calendar_id TEXT, -- ID del calendari creat pel sistema
  worker_email TEXT NOT NULL, -- Email de Google del treballador
  sync_enabled BOOLEAN DEFAULT true,
  last_sync TIMESTAMP WITH TIME ZONE,
  sync_status TEXT DEFAULT 'pending', -- 'pending', 'synced', 'error'
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT unique_worker_calendar UNIQUE (worker_name)
);

-- Index per cercar ràpidament per treballador
CREATE INDEX IF NOT EXISTS idx_worker_calendars_worker ON worker_calendars(worker_name);

-- ========================================
-- Taula: calendar_events_sync
-- Mapeja shifts locals amb events de Google Calendar
-- ========================================

CREATE TABLE IF NOT EXISTS calendar_events_sync (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  shift_date DATE NOT NULL,
  worker_name TEXT NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  lane INTEGER DEFAULT 0,
  google_event_id TEXT, -- ID de l'event a Google Calendar
  calendar_id TEXT, -- Referència al calendari
  last_synced TIMESTAMP WITH TIME ZONE,
  sync_action TEXT, -- 'create', 'update', 'delete'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index compost per trobar events per data i treballador
CREATE INDEX IF NOT EXISTS idx_calendar_events_sync_lookup 
  ON calendar_events_sync(shift_date, worker_name, start_time, end_time);

-- ========================================
-- Funció: Notificar canvis de shifts
-- Aquesta funció s'executa quan hi ha canvis a la taula shifts
-- ========================================

CREATE OR REPLACE FUNCTION notify_shift_changes()
RETURNS TRIGGER AS $$
DECLARE
  payload JSON;
  operation TEXT;
  affected_date DATE;
  affected_worker TEXT;
BEGIN
  -- Determinar l'operació i les dades afectades
  IF TG_OP = 'DELETE' THEN
    affected_date := OLD.date;
    affected_worker := OLD.worker_name;
    operation := 'delete';
    payload := json_build_object(
      'operation', operation,
      'date', OLD.date,
      'worker_name', OLD.worker_name,
      'start_time', OLD.start_time,
      'end_time', OLD.end_time,
      'lane', OLD.lane,
      'note', OLD.note
    );
  ELSE
    affected_date := NEW.date;
    affected_worker := NEW.worker_name;
    operation := CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END;
    payload := json_build_object(
      'operation', operation,
      'date', NEW.date,
      'worker_name', NEW.worker_name,
      'start_time', NEW.start_time,
      'end_time', NEW.end_time,
      'lane', NEW.lane,
      'note', NEW.note
    );
  END IF;

  -- Enviar notificació al canal 'shift_changes'
  PERFORM pg_notify('shift_changes', payload::text);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- Trigger: Detectar canvis a shifts
-- ========================================

DROP TRIGGER IF EXISTS trigger_shift_changes ON shifts;

CREATE TRIGGER trigger_shift_changes
  AFTER INSERT OR UPDATE OR DELETE ON shifts
  FOR EACH ROW
  EXECUTE FUNCTION notify_shift_changes();

-- ========================================
-- RLS (Row Level Security) per worker_calendars
-- ========================================

ALTER TABLE worker_calendars ENABLE ROW LEVEL SECURITY;

-- Només admins poden veure i modificar
CREATE POLICY "Admins can manage worker_calendars" ON worker_calendars
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Treballadors poden veure només el seu registre
CREATE POLICY "Workers can view own calendar config" ON worker_calendars
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_id = auth.uid() AND worker_name = worker_calendars.worker_name
    )
  );
