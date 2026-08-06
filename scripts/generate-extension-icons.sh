#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
source_svg="$project_root/Resources/Dia Router.icon/Assets/dia.svg"
icons_dir="$project_root/chrome-extension/icons"

if ! command -v magick >/dev/null 2>&1; then
    echo "ImageMagick is required to regenerate extension icons." >&2
    echo "Install it with: brew install imagemagick" >&2
    exit 1
fi

mkdir -p "$icons_dir"

for size in 16 32 48 128; do
    magick \
        -background none \
        -define svg:current-color="#000000" \
        "$source_svg" \
        -resize "${size}x${size}" \
        "PNG32:$icons_dir/icon${size}.png"
done

echo "Generated Chrome extension icons from $source_svg"
