#!/bin/bash

DEBUG_CHROME_FLAGS="--enable-logging --v=1"

{
  ### Variables ###

  URL=${URL:-https://www.youtube.com/watch?v=JMuzlEQz3uo}
  ONLY_VIDEO=${ONLY_VIDEO:-false}
  RESOLUTION=${RESOLUTION:-1280x720}
  FRAMERATE=${FRAMERATE:-25}
  WIDTH="$(cut -d'x' -f1 <<< $RESOLUTION)"
  HEIGHT="$(cut -d'x' -f2 <<< $RESOLUTION)"
  VIDEO_ID=${VIDEO_ID:-video}
  VIDEO_NAME=${VIDEO_NAME:-video}
  VIDEO_FORMAT=${VIDEO_FORMAT:-mp4}
  RECORDING_JSON="${RECORDING_JSON}"

  export URL
  export ONLY_VIDEO
  export RESOLUTION
  export FRAMERATE
  export WIDTH
  export HEIGHT
  export VIDEO_ID
  export VIDEO_NAME
  export VIDEO_FORMAT
  export RECORDING_JSON
  
  echo "==== Loaded Environment Variables ======================="
  env
  echo "========================================================="

  ### Store Recording json data ###

  mkdir /recordings/$VIDEO_ID

  # Cleanup to be "stateless" on startup, otherwise pulseaudio daemon can't start
  rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse
  # Run pulseaudio
  pulseaudio -D --system --disallow-exit --disallow-module-loading

  ### Start Chrome in headless mode with xvfb, using the display num previously obtained ###

  touch xvfb.log
  xvfb-run-safe --server-args="-ac -screen 0 ${RESOLUTION}x24 -noreset" google-chrome --kiosk --start-maximized --test-type --no-sandbox --disable-infobars --disable-gpu --disable-popup-blocking --window-size=$WIDTH,$HEIGHT --window-position=0,0 --no-first-run --disable-features=Translate --ignore-certificate-errors --disable-dev-shm-usage --autoplay-policy=no-user-gesture-required --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' $DEBUG_CHROME_FLAGS $URL &> xvfb.log &
  touch stop

  until pids=$(pidof Xvfb)
  do   
      sleep 0.1
  done

  ### Calculate the display num in use parsing args of command "Xvfb"

  XVFB_ARGS=$(ps -eo args | grep [X]vfb)
  DISPLAY_NUM=$(echo $XVFB_ARGS | sed 's/Xvfb :\([0-9]\+\).*/\1/')
  echo "Display in use -> :$DISPLAY_NUM"
  echo "----------------------------------------"

  sleep 1
  
  #create a not empty .mp4 because there is a mechanism to check if a .mp4 is not empty, without this, the recording stops after 1 minute...
  echo "mp4" > "/recordings/$VIDEO_ID/$VIDEO_NAME.mp4"

  ffmpeg -y -f alsa -i pulse -f x11grab -draw_mouse 0 -framerate $FRAMERATE -video_size $RESOLUTION -i :$DISPLAY_NUM  -c:v libx264 -movflags +dash -preset superfast -crf 25 -refs 4 -qmin 4 -pix_fmt yuv420p -c:a aac -ac 2 -profile:v high -bufsize 969k -hls_time 3 -hls_list_size 0 -g 30 -start_number 0 -streaming 1 -hls_playlist 1 -lhls 1 -f hls -filter:v fps=$FRAMERATE "/recordings/$VIDEO_ID/$VIDEO_NAME.m3u8" 2> "/recordings/$VIDEO_ID/$VIDEO_NAME.fflog"

} 2>&1
