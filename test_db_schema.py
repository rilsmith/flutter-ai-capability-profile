"""Tests verifying the PostgreSQL submissions schema."""

import json
import os
import uuid

import psycopg2
import pytest

os.environ.setdefault(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/capability_dashboard"
)

from init_db import init_db


@pytest.fixture
def db_conn():
    """Apply the schema and return a connection to the test database."""
    url = os.environ["DATABASE_URL"]
    init_db(url)
    conn = psycopg2.connect(url)
    try:
        yield conn
    finally:
        conn.close()


def _table_exists(cur, table_name):
    cur.execute(
        """
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (table_name,),
    )
    return cur.fetchone() is not None


def _column_exists(cur, table_name, column_name):
    cur.execute(
        """
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = %s
          AND column_name = %s
        """,
        (table_name, column_name),
    )
    return cur.fetchone() is not None


def test_submissions_table_exists(db_conn):
    with db_conn.cursor() as cur:
        assert _table_exists(cur, "submissions")


def test_submissions_columns(db_conn):
    expected = [
        "id",
        "user_uid",
        "user_email",
        "user_display_name",
        "manager_uid",
        "department_number",
        "submitted_at",
        "payload",
    ]
    with db_conn.cursor() as cur:
        for col in expected:
            assert _column_exists(cur, "submissions", col), f"Missing column {col}"


def test_id_is_uuid_primary_key_with_default(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            SELECT data_type, column_default
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'submissions'
              AND column_name = 'id'
            """
        )
        data_type, default = cur.fetchone()
        assert data_type == "uuid"
        assert "gen_random_uuid" in (default or "").lower()


def test_user_uid_and_manager_uid_not_null(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'submissions'
              AND column_name IN ('user_uid', 'manager_uid')
            """
        )
        rows = {row[0]: row[1] for row in cur.fetchall()}
    assert rows == {"user_uid": "NO", "manager_uid": "NO"}


def test_payload_is_jsonb_and_not_null(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            SELECT data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'submissions'
              AND column_name = 'payload'
            """
        )
        data_type, is_nullable = cur.fetchone()
    assert data_type == "jsonb"
    assert is_nullable == "NO"


def test_submitted_at_is_timestamptz(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            SELECT data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'submissions'
              AND column_name = 'submitted_at'
            """
        )
        assert cur.fetchone()[0] == "timestamp with time zone"


def test_required_indexes_exist(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            SELECT indexname
            FROM pg_indexes
            WHERE schemaname = 'public' AND tablename = 'submissions'
            """
        )
        indexes = {row[0] for row in cur.fetchall()}
    assert "idx_submissions_user_uid" in indexes
    assert "idx_submissions_manager_uid" in indexes
    assert "idx_submissions_submitted_at" in indexes


def test_no_secret_columns(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'submissions'
            """
        )
        columns = {row[0] for row in cur.fetchall()}
    for secret in ("token", "access_token", "client_secret", "password"):
        assert secret not in columns


def test_insert_rejects_null_user_uid(db_conn):
    with db_conn.cursor() as cur:
        with pytest.raises(psycopg2.errors.NotNullViolation):
            cur.execute(
                "INSERT INTO submissions (user_uid, manager_uid, payload) VALUES (NULL, 'mgr', '{}')"
            )
    db_conn.rollback()


def test_insert_rejects_null_manager_uid(db_conn):
    with db_conn.cursor() as cur:
        with pytest.raises(psycopg2.errors.NotNullViolation):
            cur.execute(
                "INSERT INTO submissions (user_uid, manager_uid, payload) VALUES ('user', NULL, '{}')"
            )
    db_conn.rollback()


def test_insert_rejects_null_payload(db_conn):
    with db_conn.cursor() as cur:
        with pytest.raises(psycopg2.errors.NotNullViolation):
            cur.execute(
                "INSERT INTO submissions (user_uid, manager_uid, payload) VALUES ('user', 'mgr', NULL)"
            )
    db_conn.rollback()


def test_default_uuid_and_timestamp(db_conn):
    with db_conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO submissions (user_uid, manager_uid, payload)
            VALUES ('uuid_test_user', 'uuid_test_mgr', '{}')
            RETURNING id, submitted_at
            """
        )
        row_id, submitted_at = cur.fetchone()
        parsed_id = uuid.UUID(str(row_id))
        assert parsed_id.version == 4
        assert submitted_at is not None
    db_conn.rollback()


def test_payload_jsonb_queries(db_conn):
    payload = {
        "dimensions": [{"score": 4.5}],
        "applicationDomains": [{"involvement": 3.0}],
    }
    with db_conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO submissions (user_uid, manager_uid, payload)
            VALUES ('jsonb_user', 'jsonb_mgr', %s)
            """,
            (json.dumps(payload),),
        )
        cur.execute(
            """
            SELECT payload -> 'dimensions' -> 0 ->> 'score'
            FROM submissions
            WHERE user_uid = 'jsonb_user'
            """
        )
        assert float(cur.fetchone()[0]) == 4.5
        cur.execute(
            """
            SELECT payload -> 'applicationDomains' -> 0 ->> 'involvement'
            FROM submissions
            WHERE user_uid = 'jsonb_user'
            """
        )
        assert float(cur.fetchone()[0]) == 3.0
    db_conn.rollback()
