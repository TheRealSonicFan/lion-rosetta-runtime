#!/usr/bin/python
from __future__ import print_function

import os
import re
import sys

ANALYZER_VERSION = "2"
AUDIT_CONTRACT = "carbon-gui-hitoolbox-titlebar-input-route-live-v2"
BUILD_ID = "hitoolbox-titlebar-drag-trace-v2"

INSTALL_RE = re.compile(
    r"^PM_HITOOLBOX_TITLEBAR_INPUT_HANDLER_INSTALL:"
    r"target=dispatcher status=(-?[0-9]+)$"
)
TIMER_RE = re.compile(
    r"^PM_HITOOLBOX_TITLEBAR_INPUT_TIMER:mode=([^ ]+) "
    r"from_ms=([0-9]+) to_ms=([0-9]+) exact=(YES|NO) "
    r"status=(-?[0-9]+)$"
)
EVENT_RE = re.compile(
    r"^PM_HITOOLBOX_TITLEBAR_INPUT_EVENT:index=([0-9]+) "
    r"mode=([^ ]+) kind=([0-9]+) location_status=(-?[0-9]+) "
    r"h=(-?[0-9]+) v=(-?[0-9]+) find_part=(-?[0-9]+) "
    r"find_window=(0x[0-9a-fA-F]+)$"
)
WINDOW_RE = re.compile(
    r"^CGWINDOW_OBSERVER_WINDOW:.* x=(-?[0-9]+(?:\.[0-9]+)?) "
    r"y=(-?[0-9]+(?:\.[0-9]+)?) width=400 height=222 .* "
    r"name=Rosetta PPC Carbon GUI$"
)

MOUSE_DOWN = 1
MOUSE_UP = 2
MOUSE_DRAGGED = 6
IN_DRAG = 4


def emit(fp, value=""):
    fp.write(value + "\n")


def get_scalar(lines, key):
    prefix = key + "="
    values = [line.strip().split("=", 1)[1] for line in lines
              if line.strip().startswith(prefix)]
    return values[-1] if values else None


def main():
    if len(sys.argv) != 5:
        print("usage: %s SUBJECT_LOG OUTPUT MODE MANUAL_DRAG_ATTEMPTED" % sys.argv[0],
              file=sys.stderr)
        return 64

    subject_log = sys.argv[1]
    output = sys.argv[2]
    mode = sys.argv[3].lower()
    manual = sys.argv[4].upper()

    if not os.path.isfile(subject_log):
        print("error: subject log does not exist: %s" % subject_log,
              file=sys.stderr)
        return 66

    if mode not in ("snow", "lion"):
        print("error: MODE must be snow or lion", file=sys.stderr)
        return 64
    if manual not in ("YES", "NO"):
        print("error: MANUAL_DRAG_ATTEMPTED must be YES or NO", file=sys.stderr)
        return 64

    lines = open(subject_log, "r").readlines()
    issues = []
    installs = []
    timers = []
    events = []
    positions = []

    for raw in lines:
        s = raw.strip()
        m = INSTALL_RE.match(s)
        if m:
            installs.append(int(m.group(1)))
            continue
        m = TIMER_RE.match(s)
        if m:
            timers.append(dict(
                mode=m.group(1),
                from_ms=int(m.group(2)),
                to_ms=int(m.group(3)),
                exact=m.group(4) == "YES",
                status=int(m.group(5)),
            ))
            continue
        m = EVENT_RE.match(s)
        if m:
            events.append(dict(
                index=int(m.group(1)),
                mode=m.group(2),
                kind=int(m.group(3)),
                location_status=int(m.group(4)),
                h=int(m.group(5)),
                v=int(m.group(6)),
                part=int(m.group(7)),
                window=int(m.group(8), 16),
            ))
            continue
        m = WINDOW_RE.match(s)
        if m:
            positions.append((float(m.group(1)), float(m.group(2))))

    product = get_scalar(lines, "product_version")
    build = get_scalar(lines, "build_version")
    expected_product = "10.6.8" if mode == "snow" else "10.7.5"
    expected_build = "10K549" if mode == "snow" else "11G63"
    expected_mode = "snow-passive-v2" if mode == "snow" else "lion-passive-v2"

    build_count = sum(
        1 for line in lines
        if line.strip() == "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_BUILD_ID:" + BUILD_ID
    )
    observer_pass_count = sum(
        1 for line in lines if line.strip() == "CGWINDOW_OBSERVER_RESULT:PASS"
    )
    observer_moved = any(
        abs(x - 120.0) > 0.01 or abs(y - 98.0) > 0.01
        for x, y in positions
    )

    downs = [item for item in events if item["kind"] == MOUSE_DOWN]
    ups = [item for item in events if item["kind"] == MOUSE_UP]
    drags = [item for item in events if item["kind"] == MOUSE_DRAGGED]
    down_valid = [
        item for item in downs
        if item["location_status"] == 0 and item["window"] != 0
    ]
    down_in_drag = [item for item in down_valid if item["part"] == IN_DRAG]

    if product != expected_product:
        issues.append("product version mismatch")
    if build != expected_build:
        issues.append("build version mismatch")
    if manual != "YES":
        issues.append("manual drag gesture not confirmed")
    if build_count != 1:
        issues.append("input monitor build marker count mismatch")
    if installs != [0]:
        issues.append("dispatcher event handler install mismatch")
    if len(timers) != 1:
        issues.append("subject timer marker count mismatch")
    else:
        timer = timers[0]
        if (timer["mode"] != expected_mode or
                timer["from_ms"] != 2000 or
                timer["to_ms"] != 8000 or
                not timer["exact"] or
                timer["status"] != 0):
            issues.append("subject timer extension mismatch")
    if observer_pass_count != 1:
        issues.append("WindowServer observer did not pass exactly once")
    if any(item["mode"] != expected_mode for item in events):
        issues.append("input event monitor mode mismatch")
    if not downs:
        issues.append("no mouse-down captured at dispatcher target")
    if downs and not down_valid:
        issues.append("mouse-down lacked valid public FindWindow classification")

    if mode == "snow":
        if not down_in_drag:
            issues.append("Snow mouse-down was not classified as inDrag")
        if not observer_moved:
            issues.append("Snow observer did not record window movement")
        route_state = (
            "SNOW_PUBLIC_HIT_IN_DRAG_MOVED"
            if down_in_drag and observer_moved
            else "SNOW_INPUT_CONTROL_INCOMPLETE"
        )
    else:
        if not down_valid:
            route_state = "NO_VALID_PUBLIC_HIT"
        elif down_in_drag and observer_moved:
            route_state = "PUBLIC_HIT_IN_DRAG_MOVED"
        elif down_in_drag and not observer_moved:
            route_state = "PUBLIC_HIT_IN_DRAG_NO_MOVE"
        else:
            route_state = "PUBLIC_HIT_NOT_IN_DRAG"

    fp = open(output, "w")
    try:
        emit(fp, "== PPC Carbon GUI HIToolbox titlebar input-route live summary ==")
        emit(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        emit(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        emit(fp, "mode=%s" % mode)
        emit(fp, "product_version=%s" % (product or "UNKNOWN"))
        emit(fp, "build_version=%s" % (build or "UNKNOWN"))
        emit(fp, "manual_drag_attempted=%s" % manual)
        emit(fp, "build_marker_count=%d" % build_count)
        emit(fp, "handler_install_count=%d" % len(installs))
        emit(fp, "handler_install_statuses=%s" %
             ",".join(str(value) for value in installs))
        emit(fp, "timer_marker_count=%d" % len(timers))
        if timers:
            timer = timers[-1]
            emit(fp, "timer_mode=%s" % timer["mode"])
            emit(fp, "timer_from_ms=%d" % timer["from_ms"])
            emit(fp, "timer_to_ms=%d" % timer["to_ms"])
            emit(fp, "timer_exact=%s" % ("YES" if timer["exact"] else "NO"))
            emit(fp, "timer_status=%d" % timer["status"])
        emit(fp, "observer_pass_count=%d" % observer_pass_count)
        emit(fp, "observer_position_sample_count=%d" % len(positions))
        emit(fp, "observer_moved=%s" % ("YES" if observer_moved else "NO"))

        emit(fp)
        emit(fp, "== Dispatcher mouse activity ==")
        emit(fp, "mouse_event_count=%d" % len(events))
        emit(fp, "mouse_down_count=%d" % len(downs))
        emit(fp, "mouse_dragged_count=%d" % len(drags))
        emit(fp, "mouse_up_count=%d" % len(ups))
        emit(fp, "mouse_down_valid_findwindow_count=%d" % len(down_valid))
        emit(fp, "mouse_down_in_drag_count=%d" % len(down_in_drag))
        for item in events:
            emit(fp,
                 "mouse_event index=%d kind=%d location_status=%d h=%d v=%d "
                 "find_part=%d find_window=0x%08x" % (
                     item["index"], item["kind"], item["location_status"],
                     item["h"], item["v"], item["part"], item["window"]
                 ))

        emit(fp)
        emit(fp, "== Routing discriminator ==")
        emit(fp, "routing_state=%s" % route_state)
        emit(fp, "public_FindWindow_observation_only=YES")
        emit(fp, "part_code_rewrite_authorized=NO")
        emit(fp, "private_HIToolbox_patch_authorized=NO")

        emit(fp)
        emit(fp, "== Validation ==")
        if issues:
            for issue in issues:
                emit(fp, "validation_issue=%s" % issue)
            emit(fp, "RESULT: FAIL")
        else:
            emit(fp, "titlebar_input_route_live_trace_exact=YES")
            emit(fp, "RESULT: PASS")
    finally:
        fp.close()

    print("Created: %s" % output)
    if issues:
        print("RESULT: FAIL")
        for issue in issues:
            print("validation_issue=%s" % issue)
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
