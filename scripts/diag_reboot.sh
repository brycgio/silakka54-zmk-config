#!/bin/bash
# Reboot diagnostic for Silakka54 dongle setup
# Run this AFTER rebooting, when typing is NOT working

set -e
LOG=/tmp/silakka54_diag.log
exec > >(tee "$LOG") 2>&1

echo "=== Silakka54 Reboot Diagnostic $(date) ==="
echo

echo "=== 1. Dongle USB enumeration ==="
lsusb | grep -i lily || echo "DONGLE NOT IN lsusb!"
echo

echo "=== 2. Input devices ==="
grep -B1 -A4 -i lily /proc/bus/input/devices 2>/dev/null || echo "NO Lily58 input devices!"
echo

echo "=== 3. Input device paths ==="
ls /dev/input/by-id/ 2>/dev/null | grep -i lily || echo "NO by-id Lily58"
ls /dev/input/by-path/ 2>/dev/null | grep -i "usb.*event" || echo "NO USB event by-path"
echo

echo "=== 4. hidraw devices ==="
for h in /sys/class/hidraw/hidraw*/device; do
  echo "--- $(basename $(dirname $h)) ---"
  cat "$h/uevent" 2>/dev/null | grep -E 'HID_NAME|HID_PHYS|DRIVER'
done
echo

echo "=== 5. Bluetooth state ==="
bluetoothctl show 2>&1 | head -5
echo "---"
bluetoothctl devices 2>&1
echo "---"
bluetoothctl info F3:F4:46:B9:D8:5D 2>&1 | grep -E 'Name|Connected|Paired|UUID|Battery'
echo

echo "=== 6. Battery read (forces fresh GATT read) ==="
for c in service0010/char0011 service0015/char0016 service0015/char001b; do
  v=$(gdbus call --system --dest org.bluez \
        --object-path /org/bluez/hci0/dev_F3_F4_46_B9_D8_5D/$c \
        --method org.bluez.GattCharacteristic1.ReadValue '{}' 2>&1)
  echo "  $c : $v"
done
echo

echo "=== 7. Kernel log - THIS boot (USB/HID/BT events) ==="
journalctl -b 0 -k --no-pager 2>/dev/null | grep -iE 'lily|1d50|615e|usb.*reset|hid.*error|bluetooth|btusb|hci0|disconnect|bthost|Security' | tail -40
echo

echo "=== 8. BlueZ log - THIS boot ==="
journalctl -b 0 -u bluetooth --no-pager 2>/dev/null | tail -30
echo

echo "=== 9. udev events during boot ==="
journalctl -b 0 --no-pager 2>/dev/null | grep -iE '1d50|615e|lily|hidraw.*add|input.*add' | head -20
echo

echo "=== 10. Previous boot shutdown + this boot startup ==="
journalctl -b -1 --no-pager -k 2>/dev/null | grep -iE 'lily|1d50|usb.*disconnect|usb.*reset|hid' | tail -15
echo "---"
journalctl -b 0 --no-pager -k 2>/dev/null | grep -iE 'usb.*new|usb.*reset|usb.*config|hid.*new|hid.*probe' | grep -i '1d50\|lily\|06:00.3\|usb 1-' | head -20
echo

echo "=== 11. Is dongle USB interface claimed? ==="
ls -la /sys/bus/usb/devices/1-2/1-2:1.*/driver 2>&1 | head -10
echo

echo "=== 12. Check if USB HID keyboard is sending events ==="
echo "Testing event4 (USB) for 3 seconds - press any key now..."
timeout 3 cat /dev/input/event4 2>/dev/null | xxd | head -5 || echo "  (no data or no permission)"
echo

echo "=== 13. Current USB device details ==="
lsusb -v -d 1d50:615e 2>&1 | grep -iE 'idVendor|idProduct|bcdDevice|iManufacturer|iProduct|iSerial|bInterfaceClass|bInterfaceSubClass|bInterfaceProtocol|HID' | head -20
echo

echo "=== Done. Log saved to $LOG ==="
