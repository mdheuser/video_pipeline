RESIZED_FOLDER=/Users/mdh/Documents/xxxx-2025/resized-frames-2mp
FINAL_VIDEO=/Users/mdh/Documents/xxxx-2025/final_video.mp4

# Convert images into video
cd "$RESIZED_FOLDER"
echo "Generating video..."
ffmpeg -y -framerate 30 -pattern_type glob -i "*.jpg" -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p -tune fastdecode "$FINAL_VIDEO"

echo "✅ Process completed! Your video is saved as: $FINAL_VIDEO"
