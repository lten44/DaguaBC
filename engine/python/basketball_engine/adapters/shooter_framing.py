"""Goal-anchored, clip-local subject tracking for the Windows trial."""
from __future__ import annotations

from math import ceil, dist, hypot, isfinite

import numpy as np

from .portrait import SAMPLE_FPS, _crop_size


class PersonDetector:
    """Decode the existing YOLOX Nano COCO model used by the local experiments."""

    def __init__(self, path):
        import onnxruntime as ort

        options = ort.SessionOptions()
        options.intra_op_num_threads = 2
        self.session = ort.InferenceSession(str(path), sess_options=options,
                                            providers=["CPUExecutionProvider"])
        self.input = self.session.get_inputs()[0].name
        grids, strides = [], []
        for stride in (8, 16, 32):
            grid_y, grid_x = np.mgrid[:416//stride, :416//stride]
            grids.append(np.column_stack((grid_x.ravel(), grid_y.ravel())))
            strides.extend([stride] * grid_x.size)
        self.grid = np.concatenate(grids)
        self.strides = np.array(strides)[:, None]

    def detect(self, frame):
        import cv2

        height, width = frame.shape[:2]
        scale = min(416 / width, 416 / height)
        small = cv2.resize(frame, (max(1, int(width * scale)), max(1, int(height * scale))))
        pad = np.full((416, 416, 3), 114, np.uint8)
        pad[:small.shape[0], :small.shape[1]] = small
        raw = self.session.run(None, {self.input: pad.transpose(2, 0, 1)[None].astype(np.float32)})[0][0]
        confidence = raw[:, 4] * raw[:, 5]
        mask = (confidence >= .28) & (raw[:, 5:].argmax(axis=1) == 0)
        points = (raw[mask, :2] + self.grid[mask]) * self.strides[mask] / scale
        sizes = np.exp(raw[mask, 2:4]) * self.strides[mask] / scale
        xywh = np.column_stack((points - sizes / 2, sizes))
        kept = cv2.dnn.NMSBoxes(xywh.tolist(), confidence[mask].tolist(), .28, .45)
        return [[float(x), float(y), float(x+w), float(y+h)]
                for x, y, w, h in xywh[np.asarray(kept, dtype=int).ravel()] if w >= 5 and h >= 12]


def center(box):
    return ((box[0]+box[2])/2, (box[1]+box[3])/2)


def upper_body(point, box):
    x, y = point
    left, top, right, bottom = box
    return left - .16*(right-left) <= x <= right + .16*(right-left) and (
        top - .28*(bottom-top) <= y <= top + .42*(bottom-top))


def follow_person(people, index, subject, back_frames):
    """Follow a short sequence backwards and stop at two gaps or a competing box."""
    observations = {index: center(subject)[0]}
    last = subject
    for i in range(index-1, max(-1, index-back_frames-1), -1):
        previous = center(last)
        height = last[3]-last[1]
        ranked = sorted((dist(previous, center(box)) / height, box) for box in people[i])
        if not ranked or ranked[0][0] > .34 or (
            len(ranked) > 1 and ranked[1][0] - ranked[0][0] < .09
        ):
            if min(observations) - i > 1:
                break
            continue
        last = ranked[0][1]
        observations[i] = center(last)[0]
    return observations


def find_shooter(balls, people, rim, goal_index):
    """Hypothesize a release only from a continuous flight through the goal."""
    if not rim:
        return None, "rim"
    width = rim[2] - rim[0]
    rim_x, _ = center(rim)
    plane = rim[1] + .3*(rim[3]-rim[1])
    points = [[center(box) for box in row] for row in balls]
    pairs = []
    for i in range(max(0, goal_index-7), min(len(points)-1, goal_index+7)):
        for j in range(i+1, min(len(points), i+4)):
            for a in points[i]:
                for b in points[j]:
                    if not (a[1] <= plane < b[1] and b[1]-a[1] >= .18*width):
                        continue
                    cross_x = a[0]+(b[0]-a[0])*(plane-a[1])/(b[1]-a[1])
                    if abs(cross_x-rim_x) > .55*width or dist(a,b) > width*(.7+.8*(j-i)):
                        continue
                    pairs.append((abs((i+j)/2-goal_index) + abs(cross_x-rim_x)/width,
                                  i, j, a, b))
    if not pairs:
        return None, "entry"
    _, i, j, a, b = min(pairs)
    chain = [(j,b), (i,a)]
    for k in range(i-1, max(-1, i-29), -1):
        current_i, current = chain[-1]
        next_i, following = chain[-2]
        delta = current_i-k
        if delta > 3:
            break
        prediction = tuple(x - (y-x)*delta/(next_i-current_i) for x,y in zip(current,following))
        ranked = sorted((dist(point,prediction)+.45*dist(point,current),point)
                        for point in points[k] if dist(point,current) <= width*(.45+.95*delta))
        if ranked and (len(ranked) == 1 or ranked[1][0]-ranked[0][0] > .18*width
                       or dist(ranked[0][1], ranked[1][1]) < .3*width):
            chain.append((k,ranked[0][1]))
    chain.reverse()
    for position in range(len(chain)-3, 0, -1):
        frame, contact = chain[position]
        ahead = [(t,p) for t,p in chain[position+1:] if 1 <= t-frame <= 5]
        if len(ahead) < 2 or ahead[0][1][1]-contact[1] >= -.08*width:
            continue
        departed = ahead[-1][1]
        if contact[1] - departed[1] < .38*width:
            continue
        options = [box for box in people[frame] if upper_body(contact, box)]
        if not options:
            continue
        if len(options) > 1:
            return None, "overlap"
        subject = options[0]
        if upper_body(departed, subject) or (subject[3]-subject[1]) > width*6:
            return None, "overlap"
        previous_frame, previous_point = chain[position-1]
        prior = [box for box in people[previous_frame] if upper_body(previous_point, box)]
        if frame-previous_frame > 2 or len(prior) != 1 or (
            dist(center(prior[0]), center(subject)) > .32*(subject[3]-subject[1])
        ):
            return None, "release"
        observations = follow_person(people, frame, subject, 12)
        if len(observations) < 3:
            return None, "release"
        return (frame, observations, float(center(subject)[0])), None
    return None, "release"


def aim_at_point(people, frame, x, y):
    hit = [box for box in people[frame] if box[0] <= x <= box[2] and box[1] <= y <= box[3]]
    if not hit:
        return frame, {frame: x}, x
    subject = min(hit, key=lambda box: hypot((center(box)[0]-x)/(box[2]-box[0]),
                                            (box[1]+.34*(box[3]-box[1])-y)/(box[3]-box[1])))
    return frame, follow_person(people, frame, subject, 12), center(subject)[0]


# Horizontal distances and speed are measured in portrait crop widths.
PAN_VERSION = 5
STATIC_SPAN = .62
SHOOTER_DEAD_ZONE = .10
GENTLE_TRAVEL = .24
PAN_SPEED = .75
SHOOTER_PAN_RAMP = .24


def rim_anchor(base, width, goal_index, hint):
    """Prefer the fixed-camera rim, with a stable fallback for older plans."""
    if hint is not None and isfinite(hint) and 0 <= hint <= width:
        return float(hint)
    first = min(len(base)-1, max(0, goal_index))
    return float(np.median(base[first:first+max(1, SAMPLE_FPS//3)]))


def _ease_pan(position):
    return position**3 * (10 + position * (-15 + 6*position))


def _ease_shooter_pan(position):
    # Ease into a steady speed, then mirror the ramp to settle at the rim.
    edge = np.minimum(position, 1-position)
    ramp = np.minimum(edge / SHOOTER_PAN_RAMP, 1)
    distance = SHOOTER_PAN_RAMP * (ramp**3 - .5*ramp**4)
    first_half = (distance + np.maximum(0, edge-SHOOTER_PAN_RAMP)) / (1-SHOOTER_PAN_RAMP)
    return np.where(position <= .5, first_half, 1-first_half)


def _steady_path(count, width, height, goal_index, release, shooter_x, rim_x, *, follow_shooter=False):
    crop_width, _ = _crop_size(width, height)
    half = crop_width / 2

    def clamp(center):
        return max(half, min(width-half, center))

    span = rim_x - shooter_x
    distance = abs(span)
    direction = 1 if span > 0 else -1
    midpoint = (shooter_x + rim_x) / 2
    ease = _ease_pan
    speed_factor = 1.875
    arrival_lead = 2
    if follow_shooter:
        separation = distance / crop_width
        if separation <= SHOOTER_DEAD_ZONE:
            return [clamp(shooter_x)] * count
        # Start close to the shooter's center. On wider shots leave more
        # room toward the rim at both ends so the crop can move more slowly.
        extra_span = max(0, separation - .72)
        shooter_margin = min(.13, .022 + .17 * extra_span)
        rim_margin = .287 + min(.068, .25 * extra_span)
        gentle = min(GENTLE_TRAVEL, (separation - SHOOTER_DEAD_ZONE) * .57)
        rim_offset = min(rim_margin, max(0, separation - shooter_margin - gentle))
        initial = clamp(shooter_x + direction * shooter_margin * crop_width)
        target = clamp(rim_x - direction * rim_offset * crop_width)
        ease = _ease_shooter_pan
        speed_factor = 1 / (1-SHOOTER_PAN_RAMP)
        if separation > .85:
            arrival_lead = 1
    elif distance <= STATIC_SPAN * crop_width:
        return [clamp(midpoint)] * count
    else:
        initial = clamp(shooter_x + direction * .15 * crop_width)
        target = clamp(rim_x - direction * .14 * crop_width)
    seconds = speed_factor * abs(target-initial) / (PAN_SPEED * crop_width)
    duration = max(8, ceil(seconds * SAMPLE_FPS))

    # Arrive before the basket event. Start the move ahead of release when
    # timing is tight, but do not pan away while the player sets up.
    if count == 1:
        return [target]
    end = min(count-1, max(1, goal_index-arrival_lead))
    # If the marked contact is already close to the basket event, preserve a
    # short hold at that frame even though the landing has less lead.
    end = min(count-1, max(end, min(goal_index, release+2)))
    earliest = max(0, min(end-1, release-5))
    start = max(earliest, min(release-2, end-duration))
    # Tight timing can make an early pan push the shooter out at release.
    # Start slightly later if required to keep the selected player in frame.
    if release < end:
        margin = .135 if follow_shooter else .30
        allowed = max(abs(initial-shooter_x), margin*crop_width) + 1e-6
        while start < end-1:
            release_phase = max(0, (release-start)/(end-start))
            center = initial + (target-initial) * ease(release_phase)
            if abs(center-shooter_x) <= allowed:
                break
            start += 1
    path = np.full(count, initial)
    position = np.linspace(0, 1, end-start+1)
    path[start:end+1] = initial + (target-initial) * ease(position)
    path[end:] = target
    return path.tolist()


def _possession_points(ball_points, release, shooter_x, crop_width):
    """Trace the ball back through a carry, stopping before a fast pass."""
    last_index, last_x, last_y = release + 1, shooter_x, None
    track = []
    for index in range(min(release, len(ball_points)-1), max(-1, release-4*SAMPLE_FPS-1), -1):
        gap = last_index - index
        if gap > (4 if not track else 8):
            break
        horizontal_limit = min(.40, .028 + .076*gap)*crop_width
        ranked = sorted((abs(x-last_x) + (.25*abs(y-last_y) if last_y is not None else 0), x, y)
                        for x, y in ball_points[index]
                        if abs(x-last_x) <= horizontal_limit
                        and (last_y is None or abs(y-last_y) <= (.14+.07*gap)*crop_width))
        if not ranked or (len(ranked) > 1 and ranked[1][0]-ranked[0][0] < .035*crop_width):
            continue
        _, last_x, last_y = ranked[0]
        last_index = index
        track.append((index, last_x, last_y))
    return track[::-1]


def _ball_handler(people, x, y):
    ranked = []
    for box in people:
        left, top, right, bottom = box
        width, height = right-left, bottom-top
        if left-.16*width <= x <= right+.16*width and top-.10*height <= y <= bottom+.08*height:
            ranked.append((abs(center(box)[0]-x)/width, box))
    ranked.sort(key=lambda entry: entry[0])
    if not ranked or (len(ranked) > 1 and ranked[1][0]-ranked[0][0] < .20):
        return None
    return ranked[0][1]


def _receiver_lead_in(path, width, crop_width, release, shooter_x, ball_points, people):
    track = _possession_points(ball_points, release, shooter_x, crop_width)
    contacts = [(i, x, _ball_handler(people[i], x, y)) for i, x, y in track if i < len(people)]
    for (i, _, a), (j, catch_x, b) in zip(contacts, contacts[1:]):
        if (a is None or b is None or j-i > 2 or release-j < SAMPLE_FPS
                or dist(center(a), center(b)) > .24*(b[3]-b[1])):
            continue
        receiver_x = (center(a)[0]+center(b)[0])/2
        if abs(receiver_x-path[0]) < .32*crop_width:
            return path

        # Require evidence of the ball travelling with the receiver toward
        # the release spot, with enough intermediate travel to reject jumps.
        direction = 1 if shooter_x > receiver_x else -1
        carry = direction*(shooter_x-catch_x)
        advancing = [k for k, x, _ in track
                     if k > j and .14*carry < direction*(x-catch_x) < .84*carry]
        if carry < .25*crop_width or len(advancing) < 3:
            return path

        half = crop_width/2
        initial = max(half, min(width-half, receiver_x))
        end = next((k-1 for k in range(1, release+1) if abs(path[k]-path[0]) > 1e-6), release)
        if end <= j or abs(path[end]-initial) < .06*crop_width:
            return path
        duration = ceil(abs(path[end]-initial)*SAMPLE_FPS / ((1-SHOOTER_PAN_RAMP)*PAN_SPEED*crop_width))
        if end-j < duration:
            return path
        start = max(j, min(advancing[0]-2, end-duration))
        phase = np.linspace(0, 1, end-start+1)
        lead = initial + (path[end]-initial)*_ease_shooter_pan(phase)
        return [initial]*start + lead[:-1].tolist() + path[end:]
    return path


def subject_centers(base, width, height, goal_index, subject, *, rim_x=None, ball_points=(), people=()):
    """Frame a supported receive and carry, then move from release to the rim."""
    release, _, shooter_x = subject
    target = rim_anchor(base, width, goal_index, rim_x)
    path = _steady_path(len(base), width, height, goal_index, release, shooter_x, target, follow_shooter=True)
    if not ball_points or not people:
        return path
    crop_width, _ = _crop_size(width, height)
    return _receiver_lead_in(path, width, crop_width, release, shooter_x, ball_points, people)


def steady_ball_centers(base, width, height, goal_index, *, rim_x=None):
    """Use the supported early ball framing, then hold on the basket."""
    release = max(0, goal_index-SAMPLE_FPS)
    start = max(0, release-SAMPLE_FPS//2)
    ball_x = float(np.median(base[start:release+1]))
    target = rim_anchor(base, width, goal_index, rim_x)
    return _steady_path(len(base), width, height, goal_index, release, ball_x, target)


def profile_center(profile, time_ms):
    centers = profile["centers"]
    frame = min(len(centers)-1, max(0, (time_ms-profile["start_ms"])*SAMPLE_FPS/1000))
    index = int(frame)
    return centers[index] + (centers[min(index+1,len(centers)-1)]-centers[index])*(frame-index)


def export_profile_filter(candidate):
    from .portrait import portrait_filter

    profiles = candidate["portrait_profiles"]
    width, height = profiles[0]["width"], profiles[0]["height"]
    if any((p["width"],p["height"]) != (width,height) for p in profiles):
        raise ValueError("竖屏预览的源画面尺寸不一致")
    start, end = candidate["review_start_ms"], candidate["review_end_ms"]
    step = 1000 // SAMPLE_FPS
    centers = []
    for frame_ms in range(start, end, step):
        active = [p for p in profiles if p["start_ms"] <= frame_ms < p["end_ms"]]
        if not active:
            active = [min(profiles, key=lambda p: abs(p["event_ms"]-frame_ms))]
        weights = [1 / max(200, abs(p["event_ms"]-frame_ms))**2 for p in active]
        centers.append(sum(weight*profile_center(p,frame_ms) for weight,p in zip(weights,active))/sum(weights))
    return portrait_filter(centers, width, height)
