#!/bin/sh

## Parse popular domains from URLhaus

cat URLhaus.csv | \
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
sed 's/^www\.//g' | \
# Sort and remove duplicates
sort -u | \
# Exclude Umbrella Top 1M and well-known domains
# grep match whole line
grep -Fx -f top-1m-well-known.txt > urlhaus-top-domains.txt
