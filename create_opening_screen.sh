#!/bin/bash

ffmpeg -i input.mp4 -filter_complex "
[0:v]split=2[base][progress];
[progress]trim=start=0:end='expr(t)',geq=r='255':b='0':u='255',scale=1280x20[progressbar];
[base]pad=1280:720:0:0:color=black[padded];
[padded][progressbar]overlay=x=0:y=H-h
" -c:a copy output.mp4

