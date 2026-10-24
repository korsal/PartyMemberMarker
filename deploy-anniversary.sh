#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
game_root=$(cd -- "$repo_dir/.." && pwd)
addons_dir="$game_root/_anniversary_/Interface/AddOns"
target_dir="$addons_dir/PartyMembersMarker"

if [[ ! -d "$addons_dir" ]]; then
    printf 'Anniversary AddOns directory not found: %s\n' "$addons_dir" >&2
    exit 1
fi

install -d -- "$target_dir"
install -m 0644 -- "$repo_dir/PartyMembersMarker.lua" "$target_dir/PartyMembersMarker.lua"
install -m 0644 -- "$repo_dir/PartyMembersMarker_TBC.toc" "$target_dir/PartyMembersMarker_TBC.toc"
printf 'Installed PartyMembersMarker in %s\n' "$target_dir"
