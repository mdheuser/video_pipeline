for img in /Users/mdh/Documents/xxxx-2025/frames-2mp/*.jpg; do
    ffmpeg -i "$img" -vf "scale=1620:-1,crop=1280:720:170:0" \
           "/Users/mdh/Documents/xxxx-2025/resized-frames-2mp/$(basename "$img")"
done
