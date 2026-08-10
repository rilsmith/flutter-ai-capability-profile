-- PostgreSQL schema for the AI Capability Dashboard.
-- This script is idempotent: it can be run safely on startup or as an init job.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uid TEXT NOT NULL,
    user_email TEXT,
    user_display_name TEXT,
    manager_uid TEXT NOT NULL,
    department_number TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_submissions_user_uid ON submissions(user_uid);
CREATE INDEX IF NOT EXISTS idx_submissions_manager_uid ON submissions(manager_uid);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_at ON submissions(submitted_at);
