def candidate_priority(candidate):
    verdict_rank = {"made": 3, "ambiguous": 2, "missed": 1}.get(
        candidate.get("verdict"),
        0,
    )
    gates = candidate.get("gates") if isinstance(candidate.get("gates"), dict) else {}
    source_rank = {
        "local_window": 3,
        "local_track": 2,
        "box_center_fallback": 1,
        "global": 1,
    }.get(candidate.get("rim_source"), 0)
    return (
        verdict_rank,
        candidate.get("complete_crossing") is True,
        gates.get("prediction_review") is not True,
        source_rank,
        float(candidate.get("score", 0.0)),
    )


def _crossing_span(candidate):
    """Observed approach/descent, not the padded highlight window."""
    above, below = candidate.get("above"), candidate.get("below")
    if not isinstance(above, dict) or not isinstance(below, dict):
        return None
    start, end = above.get("time"), below.get("time")
    if not isinstance(start, (int, float)) or not isinstance(end, (int, float)):
        return None
    return (start, end) if start < end else None


def candidates_are_same_event(left, right, seconds):
    if abs(float(left["time"]) - float(right["time"])) > seconds:
        return False
    # Time proximity (or overlapping highlight windows) is not event identity.
    # Only collapse repeated observations of the very same crossing. Missing
    # or different anchors stay reviewable, including fast consecutive goals.
    left_span, right_span = _crossing_span(left), _crossing_span(right)
    if left_span and right_span:
        return left.get("above") == right.get("above") and left.get("below") == right.get("below")
    return False


def dedupe_candidates(candidates, dedupe_seconds, *, audit=False):
    """Priority-first suppression; every loser conflicts with its actual winner.

    Nearby timestamps never suffice. Keep different or missing crossing
    observations and, at the engine boundary, preserve identical suppressed
    evidence so the decision can be inspected without rescanning.
    """
    ordered = sorted(candidates, key=lambda item: float(item["time"]))
    ranked = sorted(ordered, key=candidate_priority, reverse=True)
    winners = []
    for candidate in ranked:
        conflicts = [item for item in winners if candidates_are_same_event(item, candidate, dedupe_seconds)]
        if not conflicts:
            winners.append(dict(candidate) if audit else candidate)
            continue
        if audit:
            winner = min(conflicts, key=lambda item: abs(float(item["time"]) - float(candidate["time"])))
            evidence = {key: value for key, value in candidate.items() if key != "duplicate_evidence"}
            winner.setdefault("duplicate_evidence", []).append(evidence)
            winner["duplicate_evidence"].extend(candidate.get("duplicate_evidence", []))
    return sorted(winners, key=lambda item: float(item["time"]))
