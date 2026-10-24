#!/usr/bin/env bash
# Scans the added lines of a unified diff for patterns that deserve a closer look in review.
#
# Usage:
#   git diff -U0 --no-color master...HEAD | bash .claude/skills/review-pr/scripts/hotspots.sh
#
# Prints one "path:line [rule] code" line per hit. Patterns live in hotspots.tsv next to this
# script. A hit is a lead to inspect, not a finding.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

awk -F'\t' '
    # First file: the pattern table.
    FNR == NR {
        if ($0 ~ /^#/ || NF < 3) next
        count++
        path_pattern[count] = $1
        line_pattern[count] = $2
        rule[count] = $3
        next
    }

    /^\+\+\+ / {
        file = substr($0, 5)
        sub(/^b\//, "", file)
        sub(/\t.*$/, "", file)
        if (file == "/dev/null") file = ""
        if (file ~ /(^|\/)Config\/Secrets\.xcconfig$/) {
            print file ":1 [CRITICAL: gitignored secrets file is in the diff]"
        }
        next
    }

    /^--- / { next }

    /^@@ / {
        # Hunk header: @@ -old,count +new,count @@
        match($0, /\+[0-9]+/)
        line = substr($0, RSTART + 1, RLENGTH - 1) + 0
        next
    }

    # Context lines (when the diff was not made with -U0) still advance the new-file line number.
    /^ / { line++; next }

    /^\+/ {
        if (file == "") next
        code = substr($0, 2)
        trimmed = code
        sub(/^[ \t]+/, "", trimmed)
        if (file ~ /\.swift$/ && trimmed ~ /^\/\//) { line++; next }
        for (i = 1; i <= count; i++) {
            if (file ~ path_pattern[i] && code ~ line_pattern[i]) {
                shown = trimmed
                if (length(shown) > 110) shown = substr(shown, 1, 107) "..."
                print file ":" line " [" rule[i] "] " shown
                hits++
            }
        }
        line++
        next
    }

    END {
        if (hits == 0) print "No hotspot patterns in added lines."
    }
' "$script_dir/hotspots.tsv" -
