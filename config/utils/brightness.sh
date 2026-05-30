#!/bin/bash

# Configuration
BACKLIGHT_DIR="/sys/class/backlight/acpi_video0"
MAX_BRIGHT=$(cat "$BACKLIGHT_DIR/max_brightness") # Dynamically reads your 15
CURRENT_BRIGHT=$(cat "$BACKLIGHT_DIR/brightness")
STEP=1

# Default to 0 if no argument is provided
INPUT=${1:-0}

# 1. Calculate the new target brightness
if [ "$INPUT" = "up" ]; then
    NEW_BRIGHT=$((CURRENT_BRIGHT + STEP))
elif [ "$INPUT" = "down" ]; then
    NEW_BRIGHT=$((CURRENT_BRIGHT - STEP))
elif [[ "$INPUT" =~ ^[0-9]+$ ]]; then
    # If the input is a number, use it directly
    NEW_BRIGHT=$INPUT
else
    echo "Usage: $0 {up|down|<0-$MAX_BRIGHT>}"
    exit 1
fi

# 2. Clamp the value so it doesn't break sysfs bounds
if [ "$NEW_BRIGHT" -gt "$MAX_BRIGHT" ]; then
    NEW_BRIGHT=$MAX_BRIGHT
elif [ "$NEW_BRIGHT" -lt 0 ]; then
    NEW_BRIGHT=0
fi

# 3. Apply the new brightness
# Using tee here so it handles sudo gracefully if run manually
echo "$NEW_BRIGHT" | sudo tee "$BACKLIGHT_DIR/brightness" > /dev/null

echo "Brightness set to $NEW_BRIGHT/$MAX_BRIGHT"