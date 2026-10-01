#!/usr/bin/env bash
#
# Pre-generate weekly (Monday) meeting files from a template.
#
# Usage: scripts/generate-meetings.sh [START_DATE] [END_DATE]
#
#   START_DATE  First date to consider (YYYY-MM-DD). Defaults to today.
#   END_DATE    Last date to consider (YYYY-MM-DD). Defaults to Dec 31 of
#               START_DATE's year.
#
# Environment:
#   TEMPLATE    Template file to use. Defaults to scripts/template.md.
#               `{{DATE}}` in the template is replaced with the meeting date.
#
# Files are written to <repo>/<YEAR>/<YYYY-MM-DD>.md. Existing files are never
# overwritten.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
template="${TEMPLATE:-$script_dir/template.md}"

if [[ ! -f "$template" ]]; then
    echo "error: template not found: $template" >&2
    exit 1
fi

# Portable date helpers (GNU date vs. BSD/macOS date).
if date --version >/dev/null 2>&1; then
    to_epoch() { date -u -d "$1" +%s; }
    fmt_epoch() { date -u -d "@$1" "+$2"; }
else
    to_epoch() { date -u -j -f "%Y-%m-%d %H:%M:%S" "$1 00:00:00" +%s; }
    fmt_epoch() { date -u -r "$1" "+$2"; }
fi

start="${1:-$(date +%Y-%m-%d)}"
end="${2:-${start%%-*}-12-31}"

current="$(to_epoch "$start")"
end_epoch="$(to_epoch "$end")"
day=86400

# Advance to the first Monday on or after the start date (%u: 1 = Monday).
while [[ "$(fmt_epoch "$current" %u)" != "1" ]]; do
    current=$((current + day))
done

created=0
skipped=0
while (( current <= end_epoch )); do
    date_str="$(fmt_epoch "$current" %Y-%m-%d)"
    dir="$repo_root/${date_str%%-*}"
    file="$dir/$date_str.md"

    if [[ -e "$file" ]]; then
        echo "skip:   ${file#"$repo_root"/} (already exists)"
        skipped=$((skipped + 1))
    else
        mkdir -p "$dir"
        sed "s/{{DATE}}/$date_str/g" "$template" > "$file"
        echo "create: ${file#"$repo_root"/}"
        created=$((created + 1))
    fi

    current=$((current + 7 * day))
done

echo "done: $created created, $skipped skipped"
