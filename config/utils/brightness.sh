#!/bin/bash

# Set brightness to the first argument ($1). If no argument is provided, default to 0.
BRIGHTNESS=${1:-0}

# Apply the brightness setting
sudo sh -c "echo $BRIGHTNESS > /sys/class/backlight/acpi_video0/brightness"

echo "Brightness set to $BRIGHTNESS"