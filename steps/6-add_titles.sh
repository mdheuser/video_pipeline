
# Create a txt file with the names of the files to concatenate
# Content example:

# file 'title.mp4'
# file 'main_video.mp4'
# file 'closing_screen.mp4'

ffmpeg -f concat -safe 0 -i input.txt -c copy test_with_titles.mp4

#to add a black frame
# adjust duration in seconds d=10 (ten seconds)
# and resolution to match the main video
# this adds ten seconds of black frames at the beginning
# and ten at the end.
#ffmpeg -i main_video.mp4 -vf "color=c=black:s=1280x720:d=10[pre];color=c=black:s=1280x720:d=30[post];[pre][in][post]concat=n=3" output.mp4