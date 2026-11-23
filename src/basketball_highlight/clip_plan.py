"""Partition automatic highlight padding while retaining each scoring event."""
from dataclasses import dataclass, replace


@dataclass(frozen=True)
class ClipWindow:
    source: str
    start_ms: int
    end_ms: int
    event_ms: int
    protected: bool = False


def plan_nonoverlapping_windows(windows: list[ClipWindow]) -> list[ClipWindow]:
    """Split shared padding between neighboring events, without dropping events.

    Source identity is mandatory. Manual/user-trimmed ranges are protected.
    Input order is preserved for player exports and cancellation accounting.
    """
    result = list(windows)
    sources: dict[str, list[int]] = {}
    for index, window in enumerate(windows):
        if not window.protected and not window.start_ms <= window.event_ms < window.end_ms:
            raise ValueError("INVALID_CLIP_EVENT_RANGE")
        sources.setdefault(window.source, []).append(index)
    for indices in sources.values():
        ordered = sorted(indices, key=lambda index: windows[index].event_ms)
        for left_index, right_index in zip(ordered, ordered[1:]):
            left, right = result[left_index], result[right_index]
            if left.protected or right.protected or left.event_ms == right.event_ms or left.end_ms <= right.start_ms:
                continue
            boundary = max(right.start_ms, min(left.end_ms, (left.event_ms + right.event_ms) // 2))
            if left.event_ms < boundary <= right.event_ms:
                result[left_index] = replace(left, end_ms=boundary)
                result[right_index] = replace(right, start_ms=boundary)
    return result
