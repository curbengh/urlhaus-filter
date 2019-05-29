#!/bin/sh

set -e -x

## Create a temporary working folder
# -p: No error if existing
mkdir -p tmp/ && cd tmp/


## Prepare datasets
wget https://urlhaus.abuse.ch/downloads/text/ -O ../src/URLhaus.txt
wget https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip -O top-1m.csv.zip

cp ../src/exclude.txt .

## Clean up URLhaus.txt
cat ../src/URLhaus.txt | \
# Convert DOS to Unix line ending
dos2unix | \
# Remove comment
sed 's/^#.*//g' | \
# Remove http(s)://
cut -f 3- -d '/' | \
# Remove www.
sed 's/^www\.//g' | \
sort -u > urlhaus.txt

## Parse domain and IP address only
cat urlhaus.txt | \
cut -f 1 -d '/' | \
cut -f 1 -d ':' | \
sort -u > urlhaus-domains.txt


## Parse the Cisco Umbrella 1 Million
unzip -p top-1m.csv.zip | \
dos2unix | \
# Parse domains only
cut -f 2 -d ',' | \
# Domain must have at least a 'dot'
grep -F '.' | \
# Remove www.
sed 's/^www\.//g' | \
sort -u > top-1m.txt

# Merge Umbrella and self-maintained top domains
cat top-1m.txt exclude.txt | \
sort -u > top-1m-well-known.txt


## Parse popular domains from URLhaus
cat urlhaus-domains.txt | \
# grep match whole line
grep -Fx -f top-1m-well-known.txt > urlhaus-top-domains.txt


## Parse domains from URLhaus excluding popular domains
cat urlhaus-domains.txt | \
grep -F -vf urlhaus-top-domains.txt > malware-domains.txt

# Parse malware URLs from popular domains
cat urlhaus.txt | \
grep -F -f urlhaus-top-domains.txt > malware-url-top-domains.txt


## Merge malware domains and URLs
CURRENT_TIME="$(date -R -u)"
FIRST_LINE="! Title: abuse.ch URLhaus Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Expires: 1 day (update frequency)"
FOURTH_LINE="! Repo: https://gitlab.com/curben/urlhaus-filter"
FIFTH_LINE="! License: https://creativecommons.org/publicdomain/zero/1.0/"
SIXTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE\n$SIXTH_LINE"

cat malware-domains.txt malware-url-top-domains.txt | \
sort | \
sed '1 i\'"$COMMENT"'' > ../urlhaus-filter.txt


## Clean up the working folder
cd ../ && rm -r tmp/
