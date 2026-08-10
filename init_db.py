#!/usr/bin/env python3
"""Database schema initialization for the AI Capability Dashboard.

Reads the local schema.sql file and applies it to the PostgreSQL database
named by the DATABASE_URL environment variable. This can be used as a
startup script, a Kubernetes init container command, or a migration job.
"""

import logging
import os
import sys
from pathlib import Path

import psycopg2

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

SCHEMA_PATH = Path(__file__).with_name("schema.sql")


def init_db(database_url: str | None = None) -> None:
    """Apply schema.sql to the configured database."""
    if database_url is None:
        database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    sql = SCHEMA_PATH.read_text(encoding="utf-8")
    conn = psycopg2.connect(database_url)
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
        logger.info("Database schema initialized successfully.")
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        init_db()
    except Exception as exc:  # pragma: no cover - logged at startup
        logger.error("Schema initialization failed: %s", exc)
        sys.exit(1)
