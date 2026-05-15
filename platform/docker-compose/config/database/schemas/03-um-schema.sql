-- Taksa Platform User Management - PostgreSQL Schema


CREATE TABLE IF NOT EXISTS login_assist (
  email_id TEXT UNIQUE NOT NULL,
  details JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed'))
);

CREATE INDEX IF NOT EXISTS idx_login_assist_status
  ON login_assist(status);
