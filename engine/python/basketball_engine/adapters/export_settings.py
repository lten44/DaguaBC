"""Validated MP4 settings. No arbitrary FFmpeg arguments cross the protocol."""
from __future__ import annotations

from dataclasses import asdict, dataclass
import math


@dataclass(frozen=True)
class ExportSettings:
    codec: str = "h264"
    bitrate_mbps: float = 8.0
    max_height: int = 1080
    fps: int = 0
    hardware: bool = True
    remove_overlap: bool = True

    @classmethod
    def parse(cls, value: object) -> ExportSettings | None:
        if value is None:
            return None  # Historical jobs keep their recorded export behavior.
        if not isinstance(value, dict) or set(value) - set(cls.__dataclass_fields__):
            raise ValueError("INVALID_EXPORT_SETTINGS")
        settings = cls(**value)
        if settings.codec not in ("h264", "hevc"):
            raise ValueError("INVALID_EXPORT_CODEC")
        rate = settings.bitrate_mbps
        if isinstance(rate, bool) or not isinstance(rate, (int, float)) or not math.isfinite(rate) or not 2 <= rate <= 100:
            raise ValueError("INVALID_EXPORT_BITRATE")
        if type(settings.max_height) is not int or settings.max_height not in (0, 720, 1080, 1440, 2160):
            raise ValueError("INVALID_EXPORT_RESOLUTION")
        if type(settings.fps) is not int or settings.fps not in (0, 24, 25, 30, 50, 60):
            raise ValueError("INVALID_EXPORT_FPS")
        if type(settings.hardware) is not bool or type(settings.remove_overlap) is not bool:
            raise ValueError("INVALID_EXPORT_SETTINGS")
        return settings

    def json(self) -> dict[str, str | float | int | bool]:
        return asdict(self)

    def frame_size(self, width: int, height: int) -> tuple[int, int]:
        ratio = min(1.0, self.max_height / height) if self.max_height else 1.0
        return max(2, round(width * ratio / 2) * 2), max(2, round(height * ratio / 2) * 2)
