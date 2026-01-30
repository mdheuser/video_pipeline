#!/bin/bash

RESIZED_FOLDER="$HOME/Documents/xxxx-2025/resized-frames-2mp"
FINAL_VIDEO="$HOME/Documents/xxxx-2025/video_feb_14_crf-18_60-fps.mp4"

# Convert images into video
# The script is looking for jpgs without a path, so it needs to enter the folder.
cd "$RESIZED_FOLDER"
echo "Generating video..."
# -preset fast -- change to veryslow when exporting final version!
# -trying to lower quality to crf 28. Go back to 25 or less if too low.
# crg 28 is OK for now. 40 looks terrible.

ffmpeg -y -framerate 60 -pattern_type glob -i "*.jpg" \
    -c:v libx264 -preset veryslow -crf 18 -pix_fmt yuv420p \
    -tune fastdecode -profile:v baseline -threads 4 \
    -movflags +faststart "$FINAL_VIDEO"

echo "✅ Process completed! Your video is saved as: $FINAL_VIDEO"

cd ..
