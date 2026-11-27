from engine.python.basketball_engine.adapters.analysis import candidate_to_row, make_candidate_ids_unique
from engine.python.basketball_engine.storage import ProjectStore


def test_distinct_detections_at_same_millisecond_can_both_be_saved():
    rows = [candidate_to_row({"time": 12.345, "score": score}, "v", "r", 60000, 3, 1, "model")
            for score in (0.6, 0.9, 0.7)]
    original = rows[0]["id"]
    make_candidate_ids_unique(rows)
    assert [row["id"] for row in rows] == [original, original + "_1", original + "_2"]
    assert [row["score"] for row in rows] == [0.6, 0.9, 0.7]


def test_reanalysis_inherits_review_by_distance_without_consuming_it_in_list_order(tmp_path):
    store = ProjectStore(tmp_path / "project")
    store.initialize()
    store.create_project("project", "Review")
    video = store.link_video({
        "source_path": str(tmp_path / "source.mp4"),
        "source_size_bytes": 1,
        "source_mtime_ns": 1,
        "duration_ms": 40_000,
    })

    def candidate(event_seconds):
        return candidate_to_row({"time": event_seconds}, video["id"], None, 40_000, 3, 1, "test")

    original = candidate(10)
    earlier = candidate(8.5)
    closest = candidate(10.3)
    store.replace_candidates(video["id"], [original])
    store.review_candidate(original["id"], "goal")
    store.replace_candidates(video["id"], [earlier, closest])
    statuses = {item["id"]: item["review_status"] for item in store.list_candidates(video["id"])}
    assert statuses == {earlier["id"]: "pending", closest["id"]: "goal"}
