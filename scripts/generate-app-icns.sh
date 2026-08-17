#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
source_svg="$project_root/Resources/Dia Router.icon/Assets/dia.svg"
output_icns="$project_root/Resources/Dia Router.icns"

if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick is required to regenerate the app icon." >&2
    echo "Install it with: brew install imagemagick" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

iconset_dir="$work_dir/Dia Router.iconset"
master="$work_dir/master.png"

mkdir -p "$iconset_dir"

# Approximate the Icon Composer icon with the colors declared in
# Resources/Dia Router.icon/icon.json: the white dia glyph on the dark square.
# This flat rendering cannot carry the glass, specular, or dark and tinted
# specializations, so actool remains the preferred path when Xcode is present.
# The glyph is rendered at a high density and trimmed before it is scaled, so
# the dome keeps clean edges at every icon size. -size above sets the canvas,
# not the SVG render size, which is why -density carries the resolution here.
magick -size 1024x1024 xc:none \
    -fill "#201F1F" \
    -draw "roundrectangle 100,100 923,923 185,185" \
    \( -density 2048 -background none "$source_svg" \
       -trim +repage \
       -fill white -colorize 100 \
       -resize 500x500 \) \
    -gravity center -composite \
    -strip "PNG32:$master"

for entry in \
    16:icon_16x16 \
    32:icon_16x16@2x \
    32:icon_32x32 \
    64:icon_32x32@2x \
    128:icon_128x128 \
    256:icon_128x128@2x \
    256:icon_256x256 \
    512:icon_256x256@2x \
    512:icon_512x512 \
    1024:icon_512x512@2x
do
    size="${entry%%:*}"
    name="${entry##*:}"
    magick "$master" \
        -resize "${size}x${size}" \
        -strip \
        "PNG32:$iconset_dir/$name.png"
done

iconutil -c icns "$iconset_dir" -o "$output_icns"

echo "Generated $output_icns from $source_svg"
