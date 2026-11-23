"""Reversible five-second groups for the user's fixed-camera single-hoop games."""
import json
from uuid import uuid4

VISIBLE_CANDIDATE = """NOT EXISTS (SELECT 1 FROM candidate_merge_members mm
    JOIN candidate_merge_batches mb ON mb.id=mm.batch_id
    WHERE mm.candidate_id=c.id AND mb.undone=0)"""


def ensure_merge_schema(connection):
    connection.execute('''CREATE TABLE IF NOT EXISTS candidate_merge_batches (
        id TEXT PRIMARY KEY, video_id TEXT NOT NULL, snapshots_json TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        undone INTEGER NOT NULL DEFAULT 0)''')
    connection.execute('''CREATE TABLE IF NOT EXISTS candidate_merge_members (
        batch_id TEXT NOT NULL, candidate_id TEXT NOT NULL,
        PRIMARY KEY(batch_id,candidate_id))''')
    connection.execute('CREATE INDEX IF NOT EXISTS idx_merge_member_candidate ON candidate_merge_members(candidate_id)')


def merge_nearby(connection, video_id, protected_ids=()):
    rows = [dict(row) for row in connection.execute(f'''SELECT c.*,
        COALESCE(r.status,'pending') AS review_status, r.reason AS review_reason, r.player_id,
        CASE WHEN json_valid(c.evidence_json) THEN json_extract(c.evidence_json,'$.rim_check.status') END AS rim_status
        FROM candidates c
        LEFT JOIN candidate_reviews r ON r.candidate_id=c.id
        WHERE c.video_id=? AND {VISIBLE_CANDIDATE} ORDER BY c.roi_id,c.event_time_ms,c.id''', (video_id,))]
    protected_ids = set(protected_ids)
    rows = [row for row in rows if row['id'] not in protected_ids]
    bounds = {}
    for batch in connection.execute('SELECT snapshots_json FROM candidate_merge_batches WHERE video_id=? AND undone=0', (video_id,)):
        for group in json.loads(batch[0]):
            bounds[group['winner']] = (group['min_time'],group['max_time'])
    for row in rows:
        row['_min'], row['_max'] = bounds.get(row['id'], (row['event_time_ms'],row['event_time_ms']))
        # Keep automatically excluded clips separate from other decisions so
        # a possible false negative remains visible in the excluded list.
        row['_auto_excluded'] = row['review_status'] == 'excluded' and row['review_reason'] == 'auto_rim_check'
    rows.sort(key=lambda row: (row['roi_id'] or '',row['_auto_excluded'],row['_min'],row['id']))
    groups = []
    for row in rows:
        if (not groups or row['roi_id'] != groups[-1][0]['roi_id']
                or row['_auto_excluded'] != groups[-1][0]['_auto_excluded']
                or max(row['_max'], max(item['_max'] for item in groups[-1])) - groups[-1][0]['_min'] > 5000
                or not any(row['review_start_ms'] < item['review_end_ms']
                           and row['review_end_ms'] > item['review_start_ms'] for item in groups[-1])):
            groups.append([])
        groups[-1].append(row)
    snapshots = []
    count = 0
    batch_id = str(uuid4())
    for group in groups:
        if len(group) < 2 or (not group[0]['_auto_excluded'] and all(row['review_status'] == 'excluded' for row in group)):
            continue
        # Prefer an explicit confirmation, then a retained candidate. Preserve
        # all reviews unchanged; losing candidates are archived, never deleted.
        winner = max(group, key=lambda row: (
            row['review_status'] == 'goal', row['review_status'] != 'excluded',
            row['player_id'] is not None, row['detector_version'] == 'manual-v1',
            row['rim_status'] == 'made', float(row['score'] or 0), row['id']))
        start = min(row['review_start_ms'] for row in group)
        end = max(row['review_end_ms'] for row in group)
        snapshots.append({'winner': winner['id'], 'before_start': winner['review_start_ms'],
            'before_end': winner['review_end_ms'], 'after_start': start, 'after_end': end,
            'members': [row['id'] for row in group],
            'min_time': min(row['_min'] for row in group), 'max_time': max(row['_max'] for row in group)})
        connection.execute('UPDATE candidates SET review_start_ms=?,review_end_ms=? WHERE id=?', (start,end,winner['id']))
        for row in group:
            if row['id'] != winner['id']:
                connection.execute('INSERT INTO candidate_merge_members VALUES (?,?)', (batch_id,row['id']))
                count += 1
    if snapshots:
        connection.execute('INSERT INTO candidate_merge_batches (id,video_id,snapshots_json) VALUES (?,?,?)',
            (batch_id,video_id,json.dumps(snapshots)))
    return {'merged_count': count, 'group_count': len(snapshots), 'batch_id': batch_id if snapshots else None}


def scope_merge_history(connection, video_id, start, end):
    """Keep any merge group crossing the selected interval intact."""
    batches = connection.execute(
        "SELECT id,snapshots_json FROM candidate_merge_batches "
        "WHERE video_id=? AND undone=0 ORDER BY created_at DESC,rowid DESC",
        (video_id,),
    ).fetchall()
    overlapping = []
    crossing = set()
    for batch in batches:
        groups = json.loads(batch["snapshots_json"])
        overlapping.append((batch["id"], groups))
        for group in groups:
            if group["min_time"] < end and group["max_time"] >= start and (
                group["min_time"] < start or group["max_time"] >= end
            ):
                crossing.update(group["members"])
    for batch_id, groups in overlapping:
        retained = []
        for group in groups:
            if (not start <= group["min_time"] <= group["max_time"] < end
                    or crossing.intersection(group["members"])):
                retained.append(group)
                continue
            _restore_winner(connection, group)
            connection.executemany(
                "DELETE FROM candidate_merge_members WHERE batch_id=? AND candidate_id=?",
                [(batch_id, member) for member in group["members"]],
            )
        if len(retained) != len(groups):
            connection.execute(
                "UPDATE candidate_merge_batches SET snapshots_json=?,undone=? WHERE id=?",
                (json.dumps(retained), int(not retained), batch_id),
            )
    return crossing


def _restore_winner(connection, group):
    # Keep any subsequent manual range edits instead of overwriting them.
    connection.execute("""UPDATE candidates SET review_start_ms=?,review_end_ms=?
        WHERE id=? AND review_start_ms=? AND review_end_ms=?""",
        (group["before_start"], group["before_end"], group["winner"],
         group["after_start"], group["after_end"]))


def undo_merge(connection, video_id):
    row = connection.execute('''SELECT * FROM candidate_merge_batches WHERE video_id=? AND undone=0
        ORDER BY created_at DESC,rowid DESC LIMIT 1''', (video_id,)).fetchone()
    if row is None:
        return {'restored_count': 0}
    count = 0
    for group in json.loads(row['snapshots_json']):
        _restore_winner(connection, group)
        count += len(group['members']) - 1
    connection.execute('UPDATE candidate_merge_batches SET undone=1 WHERE id=?', (row['id'],))
    return {'restored_count': count}
