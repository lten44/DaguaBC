import json
from pathlib import Path
import subprocess

import pytest

from engine.python.basketball_engine.adapters import export
from engine.python.basketball_engine.adapters.export_settings import ExportSettings
from engine.python.basketball_engine.media_tools import resolve_media_tool


@pytest.mark.parametrize("settings", [
    {"bitrate_mbps": 0}, {"bitrate_mbps": True}, {"bitrate_mbps": float("nan")},
    {"max_height": -1}, {"fps": True}, {"codec": "arbitrary"}, {"extra_args": "-y"},
    {"hardware": "true"}, {"remove_overlap": "false"},
])
def test_invalid_encoding_is_rejected(settings):
    with pytest.raises((ValueError, TypeError)):
        ExportSettings.parse(settings)


def test_explicit_hevc_never_falls_back_to_a_different_format(monkeypatch):
    monkeypatch.setattr(export.platform, "system", lambda: "Windows")
    assert export.video_codecs(ExportSettings(codec="hevc")) == ["hevc_nvenc", "hevc_qsv", "hevc_amf", "libx265"]
    command = export.build_clip_command(Path("in.mp4"), 0, 1000, Path("out.mp4"), "hevc_nvenc", settings=ExportSettings(codec="hevc", bitrate_mbps=4))
    assert command[command.index("-b:v") + 1] == "4M"
    assert command[command.index("-tag:v") + 1] == "hvc1"


@pytest.mark.parametrize("effect", ["none", "approach", "replay"])
def test_real_export_keeps_events_and_does_not_repeat_shared_padding(tmp_path, effect):
    source = tmp_path / "source.mp4"
    subprocess.run([
        resolve_media_tool("ffmpeg"), "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=320x240:rate=30",
        "-t", "8", "-c:v", "mpeg4", str(source),
    ], check=True)
    events = [{"source_path": str(source), "review_start_ms": start, "review_end_ms": end,
               "event_time_ms": event, "width": 320, "height": 240, "has_audio": False}
              for start, end, event in [(0, 4550, 2000), (4000, 8000, 7100)]]
    result = export.export_goal_clips(events, tmp_path / "out", "separate", effect=effect,
                                      settings=ExportSettings(bitrate_mbps=2, fps=24))
    assert len(result["clip_files"]) == 2
    assert result["overlap_adjusted_count"] == 1
    # The first window already ends at the midpoint; only the second changes.
    assert events[1]["review_start_ms"] == 4000
    info = json.loads(subprocess.run([
        resolve_media_tool("ffprobe"), "-v", "error", "-show_streams", "-show_format", "-of", "json", result["files"][0],
    ], capture_output=True, text=True, check=True).stdout)
    assert info["streams"][0]["codec_name"] == "h264"
    assert info["streams"][0]["r_frame_rate"] == "24/1"
    if effect == "none":
        assert result["duration_ms"] == 8000
    assert result["encoding"]["bitrate_mbps"] == 2


def test_resolution_never_upscales_and_stays_even():
    settings = ExportSettings(max_height=1080)
    assert settings.frame_size(2560, 1440) == (1920, 1080)
    assert settings.frame_size(1280, 720) == (1280, 720)


def test_duplicate_events_merge_ranges_but_keep_distinct_goals_and_players():
    def clip(event, start, end, player='a'):
        return {'source_path': 'game.mp4', 'event_time_ms': event, 'player_id': player,
                'review_start_ms': start, 'review_end_ms': end}
    clips = [clip(3000, 0, 5000), clip(4500, 2000, 6500),
             clip(9000, 6000, 11000), clip(4000, 2000, 6000, 'b')]
    result = export.merge_duplicate_events(clips)
    assert [(c['event_time_ms'], c['review_start_ms'], c['review_end_ms']) for c in result] == [
        (3000, 0, 6500), (9000, 6000, 11000), (4000, 2000, 6000)]
    assert clips[0]['review_end_ms'] == 5000


def test_separate_export_combines_duplicate_clips(tmp_path):
    source = tmp_path / 'source.mp4'
    subprocess.run([resolve_media_tool('ffmpeg'), '-v', 'error', '-y', '-f', 'lavfi',
                    '-i', 'testsrc2=size=160x120:rate=25', '-t', '6', '-c:v', 'mpeg4', str(source)], check=True)
    clips = [{'source_path': str(source), 'event_time_ms': t, 'review_start_ms': a,
              'review_end_ms': b, 'player_id': 'p1', 'has_audio': False}
             for t, a, b in [(2500, 0, 4000), (3000, 1000, 6000)]]
    result = export.export_goal_clips(clips, tmp_path / 'out', 'separate', settings=ExportSettings())
    assert len(result['files']) == 1
    assert result['duration_ms'] == 6000
    assert result['merged_overlap_count'] == 1
