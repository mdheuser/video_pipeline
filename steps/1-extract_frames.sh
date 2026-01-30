#this program will enter the folder where the videos are stored and extract frames from all videos

cd /Volumes/MOTHERSHIP/NEW-xxxx-2025
for video in *.avi *.mp4 *.mkv; do
    output_folder="/Users/mdh/Documents/xxxx-2025/frames-2mp"
    mkdir -p "$output_folder"
    ffmpeg -i "$video" -vf "fps=1/2" "$output_folder/${video%.*}_frame_%09d.jpg"
done

## it is also possible to run all videos in a folder 
