#!/bin/sh

# Download the URLhaus database dump and process it to be uBO-compatible

CURRENT_TIME="$(date -R -u)"
FIRST_LINE="! Title: abuse.ch URLhaus Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Expires: 1 day (update frequency)"
FOURTH_LINE="! Repo: https://gitlab.com/curben/urlhaus-filter"
FIFTH_LINE="! License: https://creativecommons.org/publicdomain/zero/1.0/"
SIXTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE\n$SIXTH_LINE"

# Download the database dump
wget https://urlhaus.abuse.ch/downloads/csv/ -O ../src/URLhaus.csv

cat ../src/URLhaus.csv | \
# Convert DOS to Unix line ending
dos2unix | \
# Parse online URLs only
grep '"online"' | \
# Parse domains and IP address only
cut -f 6 -d '"' | \
cut -f 3 -d '/' | \
cut -f 1 -d ':' | \
# Remove www
# Only matches domains that start with www
# Not examplewww.com
sed -e 's/^www\.//g' | \
# Sort and remove duplicates
sort -u | \
# Exclude Umbrella Top 1M. grep inverse match whole line
grep -Fx -vf ../src/top-1m.txt | \
# Exclude false positive
grep -Fx -vf ../src/exclude.txt | \
# Append header comment to the filter list
sed '1 i\'"$COMMENT"'' > ../urlhaus-filter.txt

# Remove downloaded dataset
rm ../src/top-1m.txt
