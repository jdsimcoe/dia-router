#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
source_app="$project_root/build/Dia Router.app"
install_dir="$HOME/Applications"
installed_app="$install_dir/Dia Router.app"

if [[ ! -d "$source_app" ]]; then
    "$project_root/scripts/build-app.sh"
fi

mkdir -p "$install_dir"
if [[ -d "$installed_app" ]]; then
    rm -rf "$installed_app"
fi
ditto "$source_app" "$installed_app"
"$project_root/scripts/install-login-item.sh" "$installed_app"

echo "$installed_app"
