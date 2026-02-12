#!/bin/bash

# Must run as root
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
    print(f"Found device: {dev.name}")
    caps = dev.capabilities()
    # Look for device with analog stick + buttons
    if evdev.ecodes.EV_ABS in caps and evdev.ecodes.EV_KEY in caps:
        controller = dev
        break

if not controller:
    print("No compatible controller found.")
    exit(1)

print(f"Using controller: {controller.name}")

mouse = uinput.Device([
    uinput.REL_X,
    uinput.REL_Y,
    uinput.BTN_LEFT,
    uinput.BTN_RIGHT,
])

SENSITIVITY = 8
DEADZONE = 3000

for event in controller.read_loop():
    if event.type == evdev.ecodes.EV_ABS:
        if event.code == evdev.ecodes.ABS_X:
            if abs(event.value - 32768) > DEADZONE:
                dx = int((event.value - 32768) / 32768 * SENSITIVITY)
                mouse.emit(uinput.REL_X, dx)
        elif event.code == evdev.ecodes.ABS_Y:
            if abs(event.value - 32768) > DEADZONE:
                dy = int((event.value - 32768) / 32768 * SENSITIVITY)
                mouse.emit(uinput.REL_Y, dy)

    elif event.type == evdev.ecodes.EV_KEY:
        if event.code == evdev.ecodes.BTN_SOUTH:  # A button
            mouse.emit(uinput.BTN_LEFT, event.value)
        elif event.code == evdev.ecodes.BTN_EAST:  # B button
            mouse.emit(uinput.BTN_RIGHT, event.value)
EOF

chmod +x /usr/local/bin/xbox_mouse.py

echo "Done!"
echo "Starting Xbox controller as mouse..."

python3 /usr/local/bin/xbox_mouse.py
