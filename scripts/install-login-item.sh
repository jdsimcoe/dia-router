#!/bin/zsh

set -euo pipefail

app_path="${1:-$HOME/Applications/Dia Router.app}"

if [[ ! -d "$app_path" ]]; then
    echo "Dia Router is not installed at: $app_path" >&2
    echo "Run ./scripts/install-app.sh first." >&2
    exit 1
fi

open "$app_path"

echo "Dia Router opened and registered itself as a native Login Item."
echo "$app_path"
