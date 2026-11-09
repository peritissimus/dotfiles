#!/usr/bin/env bash
# tmux status: free disk space on the data volume + 1-min load average.
# Colors shift green -> yellow -> red as disk fills / load approaches core count.

vol=/System/Volumes/Data
[ -d "$vol" ] || vol=/
read -r _ _ _ avail pct _ < <(df -h "$vol" | tail -1)
pct=${pct%\%}
if   [ "$pct" -ge 90 ]; then dcol=red
elif [ "$pct" -ge 80 ]; then dcol=yellow
else                         dcol=green
fi

load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
ncpu=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
lcol=$(awk -v l="$load" -v n="$ncpu" 'BEGIN{ r=l/n; print (r>=1 ? "red" : r>=0.7 ? "yellow" : "cyan") }')

printf "#[fg=%s]%s free #[fg=#4c566a]│ #[fg=%s]%s" "$dcol" "$avail" "$lcol" "$load"
