"""Local, transactional observations for future dataset curation, not training labels."""
from __future__ import annotations

import sqlite3


_TABLES = {
    "candidates": "id",
    "candidate_reviews": "candidate_id",
    "videos": "id",
    "rois": "id",
    "players": "id",
    "exports": "id",
    "projects": "id",
    "candidate_merge_batches": "id",
    "candidate_merge_members": "candidate_id",
}
_IGNORED = {"updated_at", "reviewed_at", "review_started_at", "review_duration_ms"}


def _row_json(columns: list[str], prefix: str) -> str:
    return "json_object(" + ",".join(f"'{name}',{prefix}.{name}" for name in columns) + ")"


def _context(table: str, prefix: str, columns: dict[str, list[str]]) -> str:
    candidate_id = f"{prefix}.candidate_id" if table == "candidate_reviews" else f"{prefix}.id"
    if table in {"candidates", "candidate_reviews"}:
        video_id = f"(SELECT video_id FROM candidates WHERE id={candidate_id})" if table == "candidate_reviews" else f"{prefix}.video_id"
        roi_id = f"(SELECT roi_id FROM candidates WHERE id={candidate_id})" if table == "candidate_reviews" else f"{prefix}.roi_id"
        candidate = f"(SELECT {_row_json(columns['candidates'], 'c')} FROM candidates c WHERE c.id={candidate_id})"
        review = f"(SELECT {_row_json(columns['candidate_reviews'], 'r')} FROM candidate_reviews r WHERE r.candidate_id={candidate_id})"
    elif table == "rois":
        video_id, roi_id, candidate, review = f"{prefix}.video_id", f"{prefix}.id", "NULL", "NULL"
    elif table == "videos":
        video_id, roi_id, candidate, review = f"{prefix}.id", "NULL", "NULL", "NULL"
    else:
        video_id, roi_id, candidate, review = "NULL", "NULL", "NULL", "NULL"
    video = f"(SELECT {_row_json(columns['videos'], 'v')} FROM videos v WHERE v.id={video_id})"
    roi = f"(SELECT {_row_json(columns['rois'], 'h')} FROM rois h WHERE h.id={roi_id})"
    return f"json_object('candidate',json({candidate}),'review',json({review}),'video',json({video}),'roi',json({roi}))"


def ensure_learning_records(connection: sqlite3.Connection) -> None:
    exists = connection.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='learning_records'").fetchone()
    if exists and connection.execute("SELECT 1 FROM sqlite_master WHERE type='trigger' AND name='guabc_learning_candidate_merge_batches_insert'").fetchone():
        return
    columns = {
        table: [row[1] for row in connection.execute(f"PRAGMA table_info({table})")]
        for table in _TABLES
    }
    connection.execute("""CREATE TABLE IF NOT EXISTS learning_records (
        sequence INTEGER PRIMARY KEY AUTOINCREMENT,
        schema_version INTEGER NOT NULL DEFAULT 1,
        recorded_at TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        before_json TEXT,
        after_json TEXT,
        context_json TEXT NOT NULL,
        label_policy TEXT NOT NULL DEFAULT 'observation_only'
    )""")
    # One baseline per candidate. Never infer historical clicks or ground truth.
    if not exists:
        connection.execute(f"""INSERT INTO learning_records
        (recorded_at,entity_type,entity_id,operation,after_json,context_json)
        SELECT strftime('%Y-%m-%dT%H:%M:%fZ','now'),'candidates',c.id,'baseline',
        {_row_json(columns['candidates'], 'c')},{_context('candidates', 'c', columns)}
        FROM candidates c""")
    for table, primary_key in _TABLES.items():
        tracked = [name for name in columns[table] if name not in _IGNORED]
        for operation in ("INSERT", "UPDATE", "DELETE"):
            # BEFORE DELETE preserves source context before cascading removal.
            timing = "BEFORE" if operation == "DELETE" else "AFTER"
            prefix = "OLD" if operation == "DELETE" else "NEW"
            condition = ""
            if operation == "UPDATE":
                condition = " WHEN " + " OR ".join(f"OLD.{name} IS NOT NEW.{name}" for name in tracked)
            before = "NULL" if operation == "INSERT" else _row_json(columns[table], "OLD")
            after = "NULL" if operation == "DELETE" else _row_json(columns[table], "NEW")
            connection.execute(f"""CREATE TRIGGER IF NOT EXISTS guabc_learning_{table}_{operation.lower()}
                {timing} {operation} ON {table}{condition} BEGIN
                INSERT INTO learning_records
                (recorded_at,entity_type,entity_id,operation,before_json,after_json,context_json)
                VALUES(strftime('%Y-%m-%dT%H:%M:%fZ','now'),'{table}',{prefix}.{primary_key},
                    '{operation.lower()}',{before},{after},{_context(table, prefix, columns)});
                END""")


def learning_summary(connection: sqlite3.Connection) -> dict:
    rows = connection.execute("""SELECT entity_type,operation,COUNT(*) AS count
        FROM learning_records GROUP BY entity_type,operation""").fetchall()
    baseline = sum(row[2] for row in rows if row[1] == "baseline")
    total = sum(row[2] for row in rows)
    last = connection.execute("SELECT MAX(recorded_at) FROM learning_records").fetchone()[0]
    return {
        "schema_version": 1, "record_count": total, "baseline_count": baseline,
        "change_count": total - baseline, "last_recorded_at": last,
        "training_enabled": False, "label_policy": "observation_only",
        "counts": [{"entity_type": row[0], "operation": row[1], "count": row[2]} for row in rows],
    }
