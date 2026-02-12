#!/bin/bash

# Make sure we're running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root: sudo ./install_xbox_mouse.sh"
  exit
fi

echo "Updating package list..."
sudo apt update

echo "Installing dependencies..."
sudo apt install -y python3-pip python3-evdev python3-uinput xboxdrv

echo "Creating Python script at /usr/local/bin/xbox_mouse.py..."
cat << 'EOF' > /usr/local/bin/xbox_mouse.py
#!/usr/bin/env python3
import evdev
import uinput
from time import sleep

# Find Xbox controller
devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
controller = None
for dev in devices:
    if 'Xbox' in dev.name:
        controller = dev
        break

if not controller:
    print("Xbox controller not found!")
    exit(1)

# Setup virtual mouse
device = uinput.Device([
    uinput.REL_X,
    uinput.REL_Y,
    uinput.BTN_LEFT,
    uinput.BTN_RIGHT,
])

SENSITIVITY = 5

for event in controller.read_loop():
    if event.type == evdev.ecodes.EV_ABS:
        absevent = evdev.categorize(event)
        if absevent.event.code == evdev.ecodes.ABS_X:
            dx = int(absevent.event.value / 32768 * SENSITIVITY)
            device.emit(uinput.REL_X, dx)
        elif absevent.event.code == evdev.ecodes.ABS_Y:
            dy = int(absevent.event.value / 32768 * SENSITIVITY)
            device.emit(uinput.REL_Y, dy)
    elif event.type == evdev.ecodes.EV_KEY:
        keyevent = evdev.categorize(event)
        if keyevent.keycode == 'BTN_SOUTH':
            device.emit(uinput.BTN_LEFT, int(keyevent.keystate == evdev.KeyEvent.key_down))
        elif keyevent.keycode == 'BTN_EAST':
            device.emit(uinput.BTN_RIGHT, int(keyevent.keystate == evdev.KeyEvent.key_down))
EOF

echo "Making Python script executable..."
chmod +x /usr/local/bin/xbox_mouse.py

echo "Starting xboxdrv in background..."
sudo xboxdrv --detach-kernel-driver --silent &

echo "Running Xbox controller to mouse script..."
python3 /usr/local/bin/xbox_mouse.py
