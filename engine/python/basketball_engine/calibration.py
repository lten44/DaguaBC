"""Time-based detection regions for a single linked source video."""
import math


_COORDINATES = ("x1", "y1", "x2", "y2")


def calibration_points(value, duration_ms, width, height):
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError("CALIBRATION_POINTS_INVALID")

    def rect(data):
        try:
            x1, y1, x2, y2 = (float(data[key]) for key in _COORDINATES)
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("ROI_COORDINATES_INVALID") from exc
        if not all(math.isfinite(v) for v in (x1, y1, x2, y2)):
            raise ValueError("ROI_COORDINATES_INVALID")
        if not (0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
            raise ValueError("ROI_COORDINATES_INVALID")
        return dict(zip(_COORDINATES, (x1, y1, x2, y2)))

    clean = []
    times = set()
    for point in value:
        start = point.get("start_ms") if isinstance(point, dict) else None
        if type(start) is not int or not 0 < start < duration_ms or start in times:
            raise ValueError("CALIBRATION_TIME_INVALID")
        roi, net = rect(point.get("roi")), rect(point.get("net_roi"))
        if ((roi["x2"] - roi["x1"]) * width < max(64.0, width * 0.08)
                or (roi["y2"] - roi["y1"]) * height < max(96.0, height * 0.12)):
            raise ValueError("ROI_TOO_SMALL")
        if not (roi["x1"] <= net["x1"] < net["x2"] <= roi["x2"]
                and roi["y1"] <= net["y1"] < net["y2"] <= roi["y2"]):
            raise ValueError("NET_ROI_OUTSIDE_SHOT_ROI")
        times.add(start)
        clean.append({"start_ms": start, "roi": roi, "net_roi": net})
    return sorted(clean, key=lambda point: point["start_ms"])


def analysis_segments(video, base_roi):
    end = int(video.get("analysis_end_ms") or video["duration_ms"])
    start = int(video.get("analysis_start_ms") or 0)
    points = (base_roi.get("calibration") or {}).get("calibration_points") or []
    width, height = int(video["width"] or 0), int(video["height"] or 0)

    def source_rect(normalized):
        return {
            key: normalized[key] * (width if key.startswith("x") else height)
            for key in _COORDINATES
        }

    regions = [(0, base_roi)]
    for point in points:
        regions.append((point["start_ms"], {
            **base_roi,
            **source_rect(point["roi"]),
            "calibration": {"source": "manual", "net_roi": source_rect(point["net_roi"])},
        }))
    return [
        (max(start, since), min(end, until), roi)
        for (since, roi), (until, _) in zip(regions, [*regions[1:], (end, None)])
        if max(start, since) < min(end, until)
    ]
