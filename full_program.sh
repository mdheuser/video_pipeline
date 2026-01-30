#!/bin/bash

# Set base directory to the script location
BASE_DIR="$(pwd)"  # Assumes script is run from the directory with videos

# Set paths relative to the base directory
FRAMES_FOLDER="$BASE_DIR/frames-2mp"
RESIZED_FOLDER="$BASE_DIR/resized-frames-2mp"
EXCLUDED_FOLDER="$BASE_DIR/excluded-frames"
FINAL_VIDEO="$BASE_DIR/final_video.mp4"
PYTHON_SCRIPT="$BASE_DIR/3-delete_text.py"

# Create necessary folders
mkdir -p "$FRAMES_FOLDER" "$RESIZED_FOLDER" "$EXCLUDED_FOLDER"



# 1 - Extract frames from videos every X seconds
echo "Extracting frames from playlist..."

for video in *.avi *.mp4 *.mkv; do
    output_folder="$FRAMES_FOLDER"
    mkdir -p "$output_folder"
    ffmpeg -i "$video" -vf fps=1 "$output_folder/${video%.*}_frame_%09d.jpg" &
done
wait

# 2 - Resize and crop frames to 16:9
echo "Resizing and cropping frames..."
for img in "$FRAMES_FOLDER"/*.jpg; do
    ffmpeg -i "$img" -vf "scale=1620:-1,crop=1280:720:170:0" \
           "$RESIZED_FOLDER/$(basename "$img")"
done
wait



# 3 - Remove images with text or logos (python script)
python3 $PYTHON_SCRIPT


: '
# 4-Randomize file names -------------------------------------------------
echo "Randomizing file order and renaming sequentially..."
cd "$FRAMES_FOLDER"

# Create a temporary directory for the operation
TEMP_DIR=$(mktemp -d)

# Move all jpg files to the temporary directory with random names
find . -maxdepth 1 -type f -name "*.jpg" | while read file; do
    mv "$file" "$TEMP_DIR/$(uuidgen).jpg"
done

# Move files back with sequential names
counter=1
find "$TEMP_DIR" -type f -name "*.jpg" | sort | while read file; do
    mv "$file" "$(printf "%09d.jpg" $counter)"
    ((counter++))
done

# Remove the temporary directory
rmdir "$TEMP_DIR"

echo "Renaming complete. Files are now named sequentially from 000000001.jpg"



# 5 - Convert images into video
echo "Generating video..."
cd "$RESIZED_FOLDER"
ffmpeg -y -framerate 60 -start_number 1 -i "%09d.jpg" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p "$FINAL_VIDEO"

echo "✅ Process completed! Your video is saved as: $FINAL_VIDEO"
'