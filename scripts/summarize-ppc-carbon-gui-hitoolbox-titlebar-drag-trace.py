#!/usr/bin/python
from __future__ import print_function

import re
import sys

ANALYZER_VERSION = "1"
AUDIT_CONTRACT = "carbon-gui-hitoolbox-titlebar-drag-live-v1"
BUILD_ID = "hitoolbox-titlebar-drag-trace-v1"

DRAG_CALL_RE = re.compile(
    r"^PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_CALL:index=([0-9]+) "
    r"mode=([^ ]+) caller_offset=(0x[0-9a-fA-F]+) "
    r"hitoolbox=(YES|NO) start_h=(-?[0-9]+) start_v=(-?[0-9]+) "
    r"bounds_status=(-?[0-9]+) "
)
DRAG_RESULT_RE = re.compile(
    r"^PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_RESULT:index=([0-9]+) "
    r"caller_offset=(0x[0-9a-fA-F]+) moved=(YES|NO) "
    r"before_status=(-?[0-9]+) after_status=(-?[0-9]+) "
)
FIND_RE = re.compile(
    r"^PM_HITOOLBOX_TITLEBAR_FINDWINDOW_TRACE:index=([0-9]+) "
    r"caller_offset=(0x[0-9a-fA-F]+) hitoolbox=(YES|NO) "
    r"point_h=(-?[0-9]+) point_v=(-?[0-9]+) part=(-?[0-9]+) "
    r"window=(0x[0-9a-fA-F]+)$"
)
WINDOW_RE = re.compile(
    r"^CGWINDOW_OBSERVER_WINDOW:.* x=(-?[0-9]+(?:\.[0-9]+)?) "
    r"y=(-?[0-9]+(?:\.[0-9]+)?) width=400 height=222 .* "
    r"name=Rosetta PPC Carbon GUI$"
)

FRAMEVIEW_RETURN = 0x000b85d0
HANDLEWINDOW_RETURN = 0x0015c098


def emit(fp, value=""):
    fp.write(value + "\n")


def get_scalar(lines, key):
    prefix = key + "="
    values = [line.strip().split("=", 1)[1] for line in lines
              if line.strip().startswith(prefix)]
    return values[-1] if values else None


def fmt_offsets(values):
    return ",".join("0x%08x" % value for value in sorted(set(values)))


def main():
    if len(sys.argv) != 5:
        print("usage: %s SUBJECT_LOG OUTPUT MODE MANUAL_DRAG_ATTEMPTED" % sys.argv[0],
              file=sys.stderr)
        return 64

    subject_log = sys.argv[1]
    output = sys.argv[2]
    mode = sys.argv[3].lower()
    manual = sys.argv[4].upper()
    if mode not in ("snow", "lion"):
        print("error: MODE must be snow or lion", file=sys.stderr)
        return 64
    if manual not in ("YES", "NO"):
        print("error: MANUAL_DRAG_ATTEMPTED must be YES or NO", file=sys.stderr)
        return 64

    lines = open(subject_log, "r").readlines()
    issues = []
    calls = []
    results = []
    finds = []
    positions = []

    for raw in lines:
        s = raw.strip()
        m = DRAG_CALL_RE.match(s)
        if m:
            calls.append(dict(
                index=int(m.group(1)),
                mode=m.group(2),
                caller=int(m.group(3), 16),
                hitoolbox=m.group(4) == "YES",
                start_h=int(m.group(5)),
                start_v=int(m.group(6)),
                bounds_status=int(m.group(7)),
            ))
            continue
        m = DRAG_RESULT_RE.match(s)
        if m:
            results.append(dict(
                index=int(m.group(1)),
                caller=int(m.group(2), 16),
                moved=m.group(3) == "YES",
                before_status=int(m.group(4)),
                after_status=int(m.group(5)),
            ))
            continue
        m = FIND_RE.match(s)
        if m:
            finds.append(dict(
                index=int(m.group(1)),
                caller=int(m.group(2), 16),
                hitoolbox=m.group(3) == "YES",
                point_h=int(m.group(4)),
                point_v=int(m.group(5)),
                part=int(m.group(6)),
                window=int(m.group(7), 16),
            ))
            continue
        m = WINDOW_RE.match(s)
        if m:
            positions.append((float(m.group(1)), float(m.group(2))))

    product = get_scalar(lines, "product_version")
    build = get_scalar(lines, "build_version")
    build_count = sum(
        1 for line in lines
        if line.strip() == "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_BUILD_ID:" + BUILD_ID
    )
    observer_pass_count = sum(
        1 for line in lines if line.strip() == "CGWINDOW_OBSERVER_RESULT:PASS"
    )

    expected_mode = "snow-passive-v1" if mode == "snow" else "lion-passive-v1"
    expected_product = "10.6.8" if mode == "snow" else "10.7.5"
    expected_build = "10K549" if mode == "snow" else "11G63"

    call_indexes = [item["index"] for item in calls]
    result_indexes = [item["index"] for item in results]
    caller_offsets = [item["caller"] for item in calls]
    find_parts = [item["part"] for item in finds]
    frameview_count = sum(1 for item in calls if item["caller"] == FRAMEVIEW_RETURN)
    handlewindow_count = sum(1 for item in calls if item["caller"] == HANDLEWINDOW_RETURN)
    hitoolbox_call_count = sum(1 for item in calls if item["hitoolbox"])
    drag_moved_count = sum(1 for item in results if item["moved"])

    observer_moved = any(
        abs(x - 120.0) > 0.01 or abs(y - 98.0) > 0.01
        for x, y in positions
    )

    if product != expected_product:
        issues.append("product version mismatch")
    if build != expected_build:
        issues.append("build version mismatch")
    if build_count != 1:
        issues.append("drag trace build marker count mismatch")
    if manual != "YES":
        issues.append("manual drag gesture not confirmed")
    if observer_pass_count != 1:
        issues.append("WindowServer observer did not pass exactly once")
    if any(item["mode"] != expected_mode for item in calls):
        issues.append("drag trace mode mismatch")
    if call_indexes != result_indexes:
        issues.append("DragWindow call/result index mismatch")
    if len(calls) != len(results):
        issues.append("DragWindow call/result count mismatch")
    if any(item["before_status"] != 0 or item["after_status"] != 0 for item in results):
        issues.append("DragWindow bounds capture failed")

    if mode == "snow":
        route_state = "SNOW_DRAGWINDOW_MOVED" if calls and drag_moved_count and observer_moved else "SNOW_DRAG_CONTROL_INCOMPLETE"
        if not calls:
            issues.append("Snow manual drag did not reach DragWindow")
        if calls and hitoolbox_call_count != len(calls):
            issues.append("Snow DragWindow caller was not HIToolbox")
        if calls and frameview_count == 0 and handlewindow_count == 0:
            issues.append("Snow DragWindow caller did not match audited titlebar/window event sites")
        if drag_moved_count < 1:
            issues.append("Snow DragWindow did not report movement")
        if not observer_moved:
            issues.append("Snow observer did not record window movement")
    else:
        if not calls and not observer_moved:
            route_state = "NO_DRAGWINDOW_DISPATCH"
        elif calls and drag_moved_count == 0 and not observer_moved:
            route_state = "DRAGWINDOW_ENTERED_NO_MOVE"
        elif calls and (drag_moved_count > 0 or observer_moved):
            route_state = "DRAGWINDOW_MOVED"
        else:
            route_state = "OBSERVER_MOVED_WITHOUT_DRAGWINDOW"
        if calls and hitoolbox_call_count != len(calls):
            issues.append("Lion DragWindow caller was not HIToolbox")
        if observer_moved and drag_moved_count == 0:
            issues.append("Lion observer/DragWindow movement disagreement")

    fp = open(output, "w")
    try:
        emit(fp, "== PPC Carbon GUI HIToolbox titlebar drag live summary ==")
        emit(fp, "analyzer_version=%s" % ANALYZER_VERSION)
        emit(fp, "audit_contract=%s" % AUDIT_CONTRACT)
        emit(fp, "mode=%s" % mode)
        emit(fp, "product_version=%s" % (product or "UNKNOWN"))
        emit(fp, "build_version=%s" % (build or "UNKNOWN"))
        emit(fp, "manual_drag_attempted=%s" % manual)
        emit(fp, "build_marker_count=%d" % build_count)
        emit(fp, "observer_pass_count=%d" % observer_pass_count)
        emit(fp, "observer_position_sample_count=%d" % len(positions))
        emit(fp, "observer_moved=%s" % ("YES" if observer_moved else "NO"))

        emit(fp)
        emit(fp, "== DragWindow activity ==")
        emit(fp, "drag_call_count=%d" % len(calls))
        emit(fp, "drag_result_count=%d" % len(results))
        emit(fp, "hitoolbox_drag_call_count=%d" % hitoolbox_call_count)
        emit(fp, "frameview_drag_call_count=%d" % frameview_count)
        emit(fp, "handlewindow_drag_call_count=%d" % handlewindow_count)
        emit(fp, "drag_moved_result_count=%d" % drag_moved_count)
        emit(fp, "drag_caller_offsets=%s" % fmt_offsets(caller_offsets))
        for item in calls:
            emit(fp, "drag_call index=%d caller_offset=0x%08x hitoolbox=%s start_h=%d start_v=%d" % (
                item["index"], item["caller"],
                "YES" if item["hitoolbox"] else "NO",
                item["start_h"], item["start_v"]
            ))
        for item in results:
            emit(fp, "drag_result index=%d caller_offset=0x%08x moved=%s" % (
                item["index"], item["caller"],
                "YES" if item["moved"] else "NO"
            ))

        emit(fp)
        emit(fp, "== FindWindow activity ==")
        emit(fp, "findwindow_call_count=%d" % len(finds))
        emit(fp, "findwindow_parts=%s" % ",".join(str(value) for value in find_parts))
        for item in finds:
            emit(fp, "findwindow index=%d caller_offset=0x%08x hitoolbox=%s part=%d point_h=%d point_v=%d" % (
                item["index"], item["caller"],
                "YES" if item["hitoolbox"] else "NO",
                item["part"], item["point_h"], item["point_v"]
            ))

        emit(fp)
        emit(fp, "== Routing discriminator ==")
        emit(fp, "routing_state=%s" % route_state)
        emit(fp, "part_code_rewrite_authorized=NO")
        emit(fp, "private_HIToolbox_patch_authorized=NO")

        emit(fp)
        emit(fp, "== Validation ==")
        if issues:
            for issue in issues:
                emit(fp, "validation_issue=%s" % issue)
            emit(fp, "RESULT: FAIL")
        else:
            emit(fp, "titlebar_drag_live_trace_exact=YES")
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
