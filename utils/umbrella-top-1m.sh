#!/bin/sh

## Parse the Cisco Umbrella 1 Million
## More info:
## https://s3-us-west-1.amazonaws.com/umbrella-static/index.html

# Decompress the zip and write output to stdout
unzip -p top-1m.csv.zip | \
# Convert DOS to Unix line ending
dos2unix | \
# Parse domains only
cut -f 2 -d ',' | \
# Domain must have at least a 'dot'
grep -F '.' | \
# Remove www
# Only matches domains that start with www
# Not examplewww.com
sed 's/^www\.//g' | \
# Remove duplicates
sort -u > top-1m.txt

# Merge Umbrella and self-maintained top domains
cat top-1m.txt exclude.txt | \
sort -u > top-1m-well-known.txt
