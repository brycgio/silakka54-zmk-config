#!/bin/bash
# Flash firmware to the Holyiot 22046 dongle via Nordic DFU (usb-serial)
# Usage: ./flash_dongle.sh <firmware.hex>
#
# nRF Connect Programmer does RAW memory writes without the DFU init packet,
# which causes the bootloader to not set its "valid app" flag — the app never boots.
# This script creates a proper DFU .zip package with init packet and flashes via
# the correct Nordic DFU protocol.

set -e

HEX_FILE="${1:?Usage: $0 <firmware.hex>}"
SERIAL_PORT="${2:-/dev/ttyACM0}"

if [ ! -f "$HEX_FILE" ]; then
    echo "Error: File not found: $HEX_FILE"
    exit 1
fi

ZIP_FILE=$(mktemp --suffix=.zip /tmp/dongle_dfu_XXXXXX)

echo "=== Creating DFU package from $HEX_FILE ==="
nrfutil pkg generate \
    --application "$HEX_FILE" \
    --application-version 1 \
    --hw-version 52 \
    --sd-req 0x00 \
    --debug-mode \
    "$ZIP_FILE"

echo ""
echo "=== Flashing via DFU protocol on $SERIAL_PORT ==="
nrfutil dfu usb-serial \
    --package "$ZIP_FILE" \
    --port "$SERIAL_PORT"

rm -f "$ZIP_FILE"
echo ""
echo "Done! Dongle should auto-reset and boot."
