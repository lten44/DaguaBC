import json

from basketball_engine.adapters.portrait import _crop_size
from basketball_engine.adapters.shooter_framing import (
    PAN_VERSION, aim_at_point, find_shooter, steady_ball_centers, subject_centers,
)
from basketball_engine.service import EngineService


def _box(x, y):
    return [x-6, y-6, x+6, y+6]


def _two_attempts():
    balls = [[] for _ in range(26)]
    people = [[] for _ in balls]
    for i, point in enumerate([(670, 365), (646, 320), (610, 286), (570, 310)], 3):
        balls[i].append(_box(*point))
        people[i].append([645, 340, 695, 480])
    for i, point in enumerate([
        (550, 360), (550, 350), (550, 340), (540, 310),
        (530, 281), (513, 285), (502, 305), (501, 328),
    ], 16):
        balls[i].append(_box(*point))
    for i in range(13, 24):
        people[i].append([522, 337, 578, 477])
    return balls, people, [470, 290, 530, 324]


def test_finished_flight_centers_the_final_shooter_near_the_rim():
    balls, people, rim = _two_attempts()
    subject, reason = find_shooter(balls, people, rim, 22)
    assert reason is None
    release, observations, x = subject
    assert 16 <= release <= 19 and x == 550
    assert len(observations) >= 3
    path = subject_centers([500] * len(balls), 1600, 900, 22, subject)
    assert path == [550] * len(balls)
    assert abs(path[22]-500) < _crop_size(1600, 900)[0] / 2


def test_competing_people_leave_final_flight_for_manual_review():
    balls, people, rim = _two_attempts()
    for i in range(13, 24):
        people[i].append([536, 340, 588, 489])
    subject, reason = find_shooter(balls, people, rim, 22)
    assert subject is None and reason == "overlap"


def test_point_without_person_detection_is_still_a_manual_framing_control():
    frames = [[] for _ in range(26)]
    subject = aim_at_point(frames, 16, 1000, 330)
    path = subject_centers([500] * 36, 1600, 900, 25, subject)
    assert abs(path[16] - 1000) < .31 * _crop_size(1600, 900)[0]
    assert all(a >= b for a, b in zip(path, path[1:]))


def test_nearby_shooter_and_rim_share_one_crop_on_a_small_single_pan():
    baseline = [720, 800, 970, 790, 750] * 12
    subject = (33, {30: 1150, 31: 980, 32: 1055, 33: 1080}, 1080)
    path = subject_centers(baseline, 2560, 1440, 45, subject, rim_x=850)
    crop_width, _ = _crop_size(2560, 1440)
    assert .08 * crop_width < path[0] - path[-1] < .2 * crop_width
    assert all(a >= b for a, b in zip(path, path[1:]))
    assert abs(path[33]-1080) < .05 * crop_width
    assert all(abs(x-1080) < .3*crop_width and abs(x-850) < .3*crop_width for x in path)
    assert path[45:] == [path[45]] * (len(path)-45)


def test_almost_aligned_shooter_and_rim_keep_the_same_crop():
    baseline = [950] * 50
    subject = (35, {}, 990)
    assert subject_centers(baseline, 2560, 1440, 44, subject, rim_x=950) == [990.] * 50


def test_far_shot_has_a_single_pan_that_starts_early_and_holds_after_arrival():
    baseline = [2200, 500, 1920, 850] * 15
    goal, release, shooter_x, rim_x = 43, 32, 1630, 1070
    path = subject_centers(baseline, 2560, 1440, goal, (release, {}, shooter_x), rim_x=rim_x)
    crop_width, _ = _crop_size(2560, 1440)
    changes = [a-b for a, b in zip(path, path[1:])]
    assert path[release-1] < path[0]
    assert all(delta >= 0 for delta in changes)
    assert max(changes)*10/crop_width < .75
    assert abs(path[release]-shooter_x) < .08 * crop_width
    for i in range(release, goal + 1):
        ball_x = shooter_x + (rim_x-shooter_x) * (i-release) / (goal-release)
        assert abs(path[i]-ball_x) < .35 * crop_width
    assert path[41:] == [path[41]] * (len(path)-41)
    assert abs(path[goal]-rim_x) <= .29 * crop_width


def test_wide_shot_slows_the_pan_with_room_for_the_rim_at_the_edge():
    goal, release, shooter_x, rim_x = 46, 35, 1895, 1062
    path = subject_centers([rim_x] * 60, 2560, 1440, goal, (release, {}, shooter_x), rim_x=rim_x)
    crop_width, _ = _crop_size(2560, 1440)
    changes = [a-b for a, b in zip(path, path[1:])]
    assert all(delta >= 0 for delta in changes)
    assert max(changes)*10/crop_width < .75
    assert abs(path[release]-shooter_x) < .14 * crop_width
    assert abs(path[goal]-rim_x) < .36 * crop_width
    assert path[goal:] == [path[goal]] * (len(path)-goal)


def test_offscreen_receiver_is_framed_when_the_carry_connects_to_release():
    points = [[] for _ in range(60)]
    people = [[] for _ in points]
    for i, x in ((5, 950), (6, 710), (7, 460), (8, 220), (9, 188), (10, 178),
                 (17, 400), (18, 452), (19, 504), (20, 548), (23, 695), (27, 795),
                 (30, 823), (33, 847), (34, 873)):
        points[i].append((x, 740))
    people[9] = [[10, 630, 231, 1000]]
    people[10] = [[8, 631, 234, 1004]]
    baseline, subject = [1060] * 60, (34, {}, 830)
    previous = subject_centers(baseline, 2560, 1440, 46, subject, rim_x=1060)
    path = subject_centers(baseline, 2560, 1440, 46, subject, rim_x=1060,
                           ball_points=points, people=people)
    assert path[8:11] == [405.] * 3
    assert all(a <= b for a, b in zip(path, path[1:]))
    assert path[32:] == previous[32:]

    # A disconnected possession cannot move the crop away from the shooter.
    points[17:30] = [[] for _ in points[17:30]]
    assert subject_centers(baseline, 2560, 1440, 46, subject, rim_x=1060,
                           ball_points=points, people=people) == previous


def test_fallback_holds_rim_and_legacy_manual_choice_survives(tmp_path):
    baseline = [1500] * 31 + [1100, 1350, 930, 1150] * 8
    stable = steady_ball_centers(baseline, 2560, 1440, 43, rim_x=1000)
    assert stable[43:] == [stable[43]] * (len(stable)-43)
    old = {"base": baseline, "centers": baseline, "width": 2560, "height": 1440,
           "goal_index": 43, "status": "manual", "release_index": 32,
           "release_ms": 3200, "subject_x": .62}
    plan_path = tmp_path / "plan.json"
    plan_path.write_text(json.dumps(old), encoding="utf-8")
    plan, upgraded = EngineService._read_portrait_trial(plan_path, {"rim": {"x": 1000}})
    assert upgraded and plan["pan_version"] == PAN_VERSION
    assert (plan["status"], plan["subject_x"], plan["release_ms"]) == ("manual", .62, 3200)
    assert plan["centers"][43:] == [plan["centers"][43]] * (len(baseline)-43)
