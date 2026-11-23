from engine.python.basketball_engine.adapters.analysis import candidate_to_row, make_candidate_ids_unique


def test_distinct_detections_at_same_millisecond_can_both_be_saved():
    rows = [candidate_to_row({"time": 12.345, "score": score}, "v", "r", 60000, 3, 1, "model")
            for score in (0.6, 0.9, 0.7)]
    original = rows[0]["id"]
    make_candidate_ids_unique(rows)
    assert [row["id"] for row in rows] == [original, original + "_1", original + "_2"]
    assert [row["score"] for row in rows] == [0.6, 0.9, 0.7]
