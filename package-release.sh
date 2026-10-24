#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
version=$(git -C "$repo_dir" show HEAD:PartyMembersMarker.toc | sed -n 's/^## Version: //p')
tbc_version=$(git -C "$repo_dir" show HEAD:PartyMembersMarker_TBC.toc | sed -n 's/^## Version: //p')

if [[ -z "$version" || "$version" != "$tbc_version" ]]; then
    printf 'Committed TOC versions are missing or differ.\n' >&2
    exit 1
fi

output=${1:-"$repo_dir/../PartyMembersMarker-$version.zip"}
git -C "$repo_dir" archive --format=zip --prefix=PartyMembersMarker/ \
    --output="$output" HEAD \
    PartyMembersMarker.lua PartyMembersMarker.toc PartyMembersMarker_TBC.toc
printf 'Created %s\n' "$output"
