#!/bin/sh

set -e -x

## Create a temporary working folder
mkdir -p tmp/ && cd tmp/


## Prepare datasets
wget https://urlhaus.abuse.ch/downloads/csv/ -O ../src/URLhaus.csv
wget https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip -O top-1m.csv.zip

cp ../src/exclude.txt .

## Clean up URLhaus.csv
cat ../src/URLhaus.csv | \
# Convert DOS to Unix line ending
dos2unix | \
# Remove comment
sed '/^#/d' | \
# Parse URLs
cut -f 6 -d '"' | \
cut -f 3- -d '/' | \
# Domain must have at least a 'dot'
grep -F '.' | \
# Remove www.
sed 's/^www\.//g' | \
sort -u > urlhaus.txt

## Parse domain and IP address only
cat urlhaus.txt | \
cut -f 1 -d '/' | \
cut -f 1 -d ':' | \
sort -u > urlhaus-domains.txt

cat ../src/URLhaus.csv | \
dos2unix | \
sed '/^#/d' | \
# Parse online URLs only
grep '"online"' | \
cut -f 6 -d '"' | \
cut -f 3- -d '/' | \
sed 's/^www\.//g' | \
sort -u > urlhaus-online.txt

cat urlhaus-online.txt | \
cut -f 1 -d '/' | \
cut -f 1 -d ':' | \
sort -u > urlhaus-domains-online.txt


## Parse the Cisco Umbrella 1 Million
unzip -p top-1m.csv.zip | \
dos2unix | \
# Parse domains only
cut -f 2 -d ',' | \
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

cat urlhaus-domains-online.txt | \
grep -F -vf urlhaus-top-domains.txt > malware-domains-online.txt

## Parse malware URLs from popular domains
cat urlhaus.txt | \
grep -F -f urlhaus-top-domains.txt > malware-url-top-domains.txt

cat urlhaus-online.txt | \
grep -F -f urlhaus-top-domains.txt > malware-url-top-domains-online.txt


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

cat malware-domains-online.txt malware-url-top-domains-online.txt | \
sort | \
sed '1 i\'"$COMMENT"'' | \
sed '1s/Malicious/Online Malicious/' > ../urlhaus-filter-online.txt


## Host-only blocklist
FIRST_LINE="# Title: abuse.ch URLhaus Malicious Hosts Blocklist"
SECOND_LINE="# Updated: $CURRENT_TIME"
THIRD_LINE="# Repo: https://gitlab.com/curben/urlhaus-filter"
FOURTH_LINE="# License: https://creativecommons.org/publicdomain/zero/1.0/"
FIFTH_LINE="# Source: https://urlhaus.abuse.ch/api/"
COMMENT="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE"

cat malware-domains.txt | \
sort | \
sed '1 i\'"$COMMENT"'' > ../urlhaus-filter-hosts.txt

cat malware-domains-online.txt | \
sort | \
sed '1 i\'"$COMMENT"'' | \
sed '1s/Malicious/Online Malicious/' > ../urlhaus-filter-hosts-online.txt

cd ../ && rm -r tmp/
