#!/bin/bash
# GRID_BREAKER — App Store promo preview build.
# In : docs/preview/app-preview-6.9.mov  (1320x2868 ~50fps, no audio)
# Out: app-preview-promo-886x1920.mov    (App Preview spec: 886x1920, 30fps, H.264 + AAC)
# Adds: bloom pass (neon glow boost), light grade, timed neon captions, music bed.
set -euo pipefail

IN="$(dirname "$0")/../docs/preview/app-preview-6.9.mov"
MUSIC="$(dirname "$0")/../App/GRID_BREAKER/Music/Arcade_Fever.mp3"
OUT="$(dirname "$0")/../docs/preview/app-preview-promo-886x1920.mov"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
CYAN="0x4DF7FF"; GOLD="0xFFC845"

# caption helper: fade in/out 0.3s via alpha expression
cap() { # text, t1, t2, color, size, y
  local TXT="$1" T1="$2" T2="$3" COL="$4" SZ="$5" Y="$6"
  echo "drawtext=fontfile=${FONT}:text='${TXT}':fontsize=${SZ}:fontcolor=${COL}:\
borderw=7:bordercolor=${COL}@0.28:shadowx=0:shadowy=0:\
x=(w-text_w)/2:y=${Y}:\
alpha='if(lt(t,${T1}),0,if(lt(t,${T1}+0.3),(t-${T1})/0.3,if(lt(t,${T2}-0.3),1,if(lt(t,${T2}),(${T2}-t)/0.3,0))))'"
}

VF="fps=30,scale=886:1920:flags=lanczos,setsar=1,\
split[base][forblur];[forblur]gblur=sigma=8[blur];\
[base][blur]blend=all_mode=screen:all_opacity=0.16,\
eq=saturation=1.12:contrast=1.10:brightness=-0.025,\
$(cap 'BREACH THE GRID'      0.8  2.8  $GOLD 46 1718),\
$(cap 'TAP · DECODE · SURVIVE' 3.2 6.2 $CYAN 42 1718),\
$(cap 'OVERCLOCK THE RUN'    6.8  9.6  $GOLD 46 1718),\
$(cap 'CHAIN FEVER MODE'     10.0 13.0 $GOLD 46 1718),\
$(cap 'BUILD YOUR STREAK'    13.6 16.2 $CYAN 46 1718),\
$(cap 'THE GRID GROWS'       16.6 19.4 $CYAN 46 1718),\
$(cap 'MULTIPLY EVERYTHING'  19.8 22.4 $GOLD 44 1718),\
$(cap 'JACK IN NOW'          22.9 25.3 $GOLD 72 920)"

ffmpeg -y -v error -i "$IN" -i "$MUSIC" \
  -filter_complex "[0:v]${VF}[v];[1:a]atrim=0:25.49,afade=t=in:d=0.5,afade=t=out:st=23.6:d=1.85,volume=0.9[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -profile:v high -preset slow -crf 18 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -movflags +faststart -shortest "$OUT"

ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,avg_frame_rate "$OUT"
