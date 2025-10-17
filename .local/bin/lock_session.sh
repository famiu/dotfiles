WALLPAPER="$(swww query | grep eDP-1 | awk -F 'currently displaying: image: ' '{print $2}')"
WALLPAPER_HASH="$(md5sum "$WALLPAPER" | awk '{print $1}')"

mkdir -p /tmp/swaylock_bg
BLURRED_WALLPAPER="/tmp/swaylock_bg/$WALLPAPER_HASH"

if test ! -f "$BLURRED_WALLPAPER"; then
    magick "$WALLPAPER" -scale 10% -blur 0x2 -resize 1000% "$BLURRED_WALLPAPER"
fi

swaylock \
    --ring-color '#121417' --inside-color '#000000' \
    --inside-clear-color '#000000' --ring-clear-color '#BC9F76' \
    --inside-ver-color '#000000' --ring-ver-color '#344252' \
    --inside-wrong-color '#000000' --ring-wrong-color '#BF8585' \
    --bs-hl-color '#BF8585' --font='Roboto Mono' \
    --indicator-idle-visible --indicator-radius 80 --key-hl-color '#344252' \
    -Ki "$BLURRED_WALLPAPER"
