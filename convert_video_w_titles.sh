

ffmpeg -y -framerate 60 -pattern_type glob -i "*.jpg" \
-i title_image.png -t 5 -framerate 60 -loop 1 -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p \
-profile:v high -level 4.1 -r 60 -threads 4 \
-filter_complex "[1:v]tpad=stop_mode=clone:stop_duration=5[v_title]; [v_title][0:v]concat=n=2:v=1:a=0[v]" \
-map "[v]" -map 0:a? "$FINAL_VIDEO"
