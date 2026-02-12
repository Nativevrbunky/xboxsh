#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "Please run with: sudo bash install_xbox_mouse.sh"
  exit 1
fi

echo "Updating packages..."
apt update

echo "Installing dependencies..."
apt install -y python3-evdev python3-uinput

echo "Creating Xbox mouse script..."

cat << 'EOF' > /usr/local/bin/xbox_mouse.py
#!/usr/bin/env python3
import evdev
import uinput

print("Searching for controller...")

devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
controller = None

for dev in devices:
    caps = dev.capabilities()
    if evdev.ecodes.EV_ABS in caps and evdev.ecodes.EV_KEY in caps:
        print("Using device:", dev.name)
        controller = dev
        break

if not controller:
    print("No compatible controller found.")
    exit(1)

mouse = uinput.Device([
    uinput.REL_X,
    uinput.REL_Y,
    uinput.BTN_LEFT,
    uinput.BTN_RIGHT,
])

SENSITIVITY = 0.0005
DEADZONE = 4000

for event in controller.read_loop():
    if event.type == evdev.ecodes.EV_ABS:
        # LEFT STICK X
        if event.code == evdev.ecodes.ABS_X:
            if abs(event.value) > DEADZONE:
                dx = int(event.value * SENSITIVITY)
                mouse.emit(uinput.REL_X, dx)

        # LEFT STICK Y
        elif event.code == evdev.ecodes.ABS_Y:
            if abs(event.value) > DEADZONE:
                dy = int(event.value * SENSITIVITY)
                mouse.emit(uinput.REL_Y, dy)

    elif event.type == evdev.ecodes.EV_KEY:
        # A button = left click
        if event.code == evdev.ecodes.BTN_SOUTH:
            mouse.emit(uinput.BTN_LEFT, event.value)

        # B button = right click
        elif event.code == evdev.ecodes.BTN_EAST:
            mouse.emit(uinput.BTN_RIGHT, event.value)
EOF

chmod +x /usr/local/bin/xbox_mouse.py

echo "Starting controller as mouse..."
python3 /usr/local/bin/xbox_mouse.py
