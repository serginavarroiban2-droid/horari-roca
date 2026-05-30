-- Migration: 20260530_shifts_backup.sql
-- Description: Sistema de còpia de seguretat automàtica per a tots els torns (logs d'auditoria)

-- Taula per emmagatzemar l'historial de tots els canvis als torns
CREATE TABLE IF NOT EXISTS shifts_backup (
    id BIGSERIAL PRIMARY KEY,
    shift_id TEXT, -- ID del torn (emmagatzemat com a text per compatibilitat)
    worker_name TEXT,
    date DATE,
    start_time TIME,
    end_time TIME,
    lane INTEGER,
    note TEXT,
    operation TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    changed_by UUID, -- ID de l'usuari que ha fet el canvi (si n'hi ha)
    old_data JSONB, -- Dades anteriors (per a updates i deletes)
    new_data JSONB  -- Dades noves (per a inserts i updates)
);

-- Indexs per millorar el rendiment de les cerques a la recerca de còpies
CREATE INDEX IF NOT EXISTS idx_shifts_backup_worker_name ON shifts_backup(worker_name);
CREATE INDEX IF NOT EXISTS idx_shifts_backup_date ON shifts_backup(date);
CREATE INDEX IF NOT EXISTS idx_shifts_backup_changed_at ON shifts_backup(changed_at);

-- Funció per gestionar les còpies de seguretat automàtiques
CREATE OR REPLACE FUNCTION handle_shift_backup()
RETURNS TRIGGER AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Intentar obtenir l'ID de l'usuari actual de Supabase
    BEGIN
        current_user_id := auth.uid();
    EXCEPTION WHEN OTHERS THEN
        current_user_id := NULL;
    END;

    IF (TG_OP = 'DELETE') THEN
        INSERT INTO shifts_backup (
            shift_id, worker_name, date, start_time, end_time, lane, note, 
            operation, changed_by, old_data
        ) VALUES (
            OLD.id::text, OLD.worker_name, OLD.date, OLD.start_time, OLD.end_time, OLD.lane, OLD.note,
            'DELETE', current_user_id, to_jsonb(OLD)
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO shifts_backup (
            shift_id, worker_name, date, start_time, end_time, lane, note, 
            operation, changed_by, old_data, new_data
        ) VALUES (
            NEW.id::text, NEW.worker_name, NEW.date, NEW.start_time, NEW.end_time, NEW.lane, NEW.note,
            'UPDATE', current_user_id, to_jsonb(OLD), to_jsonb(NEW)
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO shifts_backup (
            shift_id, worker_name, date, start_time, end_time, lane, note, 
            operation, changed_by, new_data
        ) VALUES (
            NEW.id::text, NEW.worker_name, NEW.date, NEW.start_time, NEW.end_time, NEW.lane, NEW.note,
            'INSERT', current_user_id, to_jsonb(NEW)
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger per executar la funció de còpia de seguretat
DROP TRIGGER IF EXISTS trigger_shifts_backup ON shifts;
CREATE TRIGGER trigger_shifts_backup
AFTER INSERT OR UPDATE OR DELETE ON shifts
FOR EACH ROW EXECUTE FUNCTION handle_shift_backup();

-- Comentari informatiu
COMMENT ON TABLE shifts_backup IS 'Taula que manté un historial complet de tots els canvis fets a la taula de torns (shifts).';
