#!/usr/bin/env bash

# Get current date
current_date=$(date +%s)
current_month=$(date +%-m)
current_year=$(date +%Y)

# Determine current quarter
if [ $current_month -le 3 ]; then
    quarter=1
    end_month=3
    end_day=31
elif [ $current_month -le 6 ]; then
    quarter=2
    end_month=6
    end_day=30
elif [ $current_month -le 9 ]; then
    quarter=3
    end_month=9
    end_day=30
else
    quarter=4
    end_month=12
    end_day=31
fi

# Calculate end of quarter date
end_of_quarter=$(date -j -f "%Y-%m-%d" "$current_year-$end_month-$end_day" +%s 2>/dev/null || date -d "$current_year-$end_month-$end_day" +%s)

# Calculate days remaining
days_remaining=$(( ($end_of_quarter - $current_date) / 86400 + 1 ))

# Output result
echo "Q$quarter $current_year: $days_remaining days remaining"