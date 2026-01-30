#!/bin/bash

# Find all video files in the specified formats
video_files=$(find . -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \))

# Check if any files were found
if [ -z "$video_files" ]; then
  echo "No video files found in the specified formats."
  exit 0
fi

# Calculate total duration using ffprobe
total_seconds=$(echo "$video_files" | while read -r file; do
  ffprobe -v quiet -of csv=p=0 -show_entries format=duration "$file"
done | paste -sd+ - | bc)

# Convert total seconds to HH:MM:SS format
hours=$((total_seconds / 3600))
minutes=$(((total_seconds % 3600) / 60))
seconds=$((total_seconds % 60))

# Display the total duration in HH:MM:SS format
printf "Total duration: %02d:%02d:%02d\n" $hours $minutes $seconds


##################################

video_files=$(find . -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \))
if [ -z "$video_files" ]; then
  echo "No video files found in the specified formats."
  exit 0
fi
total_seconds=$(echo "$video_files" | while read -r file; do
  ffprobe -v quiet -of csv=p=0 -show_entries format=duration "$file"
done | paste -sd+ - | bc)
hours=$((total_seconds / 3600))
minutes=$(((total_seconds % 3600) / 60))
seconds=$((total_seconds % 60))
printf "Total duration: %02d:%02d:%02d\n" $hours $minutes $seconds