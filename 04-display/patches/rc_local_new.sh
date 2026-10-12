# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

amixer cset name="HPOUT Switch" 1

# capture
amixer -Dhw:audiocodec cset name='MIC3 Input Select' 1
amixer -Dhw:audiocodec cset name='MIC3 Switch' 1
amixer -Dhw:audiocodec cset name='ADC3 Gain' 19

# display colorbar (persist across reset) - wait for disp driver ready
for i in 1 2 3 4 5; do
    if [ -e /sys/class/disp/disp/attr/colorbar ]; then
        break
    fi
    sleep 1
done
echo 1 > /sys/class/disp/disp/attr/colorbar

exit 0
