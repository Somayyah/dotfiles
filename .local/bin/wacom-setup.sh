#!/bin/bash
# Wait for tablet to be detected
sleep 3
if xsetwacom --list devices | grep -q "Wacom Intuos BT M"; then
    # Reattach pen to master pointer (floating mode doesn't move cursor on this system)
    pen_id=$(xinput list | grep "Wacom Intuos BT M Pen stylus" | grep -oP 'id=\K\d+')
    [ -n "$pen_id" ] && xinput reattach "$pen_id" 2

    xsetwacom --set "Wacom Intuos BT M Pad pad" Button 1 "key ctrl z"
    xsetwacom --set "Wacom Intuos BT M Pad pad" Button 2 "key b"
    xsetwacom --set "Wacom Intuos BT M Pad pad" Button 3 "key e"
    xsetwacom --set "Wacom Intuos BT M Pad pad" Button 8 "key +Shift_L -Shift_L"
    xsetwacom --set "Wacom Intuos BT M Pen stylus" PressureCurve 0 15 85 100
    xsetwacom --set "Wacom Intuos BT M Pen stylus" MapToOutput "desktop"
    xsetwacom --set "Wacom Intuos BT M Pen stylus" CursorProximity 50
fi
