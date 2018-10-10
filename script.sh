#!/bin/sh

# Download the URLhaus database dump and process it to be uBO-compatible

CURRENT_TIME="$(date -R -u)"
FIRST_LINE="! Title: abuse.ch URLhaus Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Repo: https://gitlab.com/curben/urlhaus"
FOURTH_LINE="! License: https://creativecommons.org/publicdomain/zero/1.0/"
FIFTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE"

# Download the database dump
wget https://urlhaus.abuse.ch/downloads/csv/ -O URLhaus.csv

# Parse domains and IP address only
cat URLhaus.csv | \
grep '"online"' | \
cut -f 6 -d '"' | \
cut -f 3 -d '/' | \
cut -f 1 -d ':' | \
# Sort and remove duplicates
sort -u | \
# Exclude Umbrella Top 1M
grep -vf top-1m.txt | \
# Exclude false positive
grep -vf exclude.txt | \
# Append header comment to the filter list
sed '1 i\'"$COMMENT"'' > urlhaus-filter.txt
