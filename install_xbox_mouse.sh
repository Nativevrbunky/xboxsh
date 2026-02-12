#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "Please run with: sudo bash install_xbox_mouse.sh"
  exit 1
fi

echo "Updating packages..."
apt update

echo "Installing dependencies..."
apt install -y python3-evdev

echo "Creating Xbox mouse script..."

cat << 'EOF' > /usr/local/bin/xbox_mouse.py
#!/usr/bin/env python3
import evdev
from evdev import UInput, ecodes as e

print("Searching for controller...")

devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
controller = None

for dev in devices:
    caps = dev.capabilities()
    if e.EV_ABS in caps and e.EV_KEY in caps:
        print("Using device:", dev.name)
        controller = dev
        break

if not controller:
    print("No compatible controller found.")
    exit(1)

cap = {
    e.EV_REL: [e.REL_X, e.REL_Y],
    e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT],
}

ui = UInput(cap, name="Xbox Mouse")

SENSITIVITY = 0.0006
DEADZONE = 4000

for event in controller.read_loop():
    if event.type == e.EV_ABS:
        if event.code == e.ABS_X:
            if abs(event.value) > DEADZONE:
                dx = int(event.value * SENSITIVITY)
                ui.write(e.EV_REL, e.REL_X, dx)
                ui.syn()

        elif event.code == e.ABS_Y:
            if abs(event.value) > DEADZONE:
                dy = int(event.value * SENSITIVITY)
                ui.write(e.EV_REL, e.REL_Y, dy)
                ui.syn()

    elif event.type == e.EV_KEY:
        if event.code == e.BTN_SOUTH:
            ui.write(e.EV_KEY, e.BTN_LEFT, event.value)
            ui.syn()

        elif event.code == e.BTN_EAST:
            ui.write(e.EV_KEY, e.BTN_RIGHT, event.value)
            ui.syn()
EOF

chmod +x /usr/local/bin/xbox_mouse.py

echo "Starting controller as mouse..."
python3 /usr/local/bin/xbox_mouse.py
