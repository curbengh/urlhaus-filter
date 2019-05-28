#!/bin/sh

set -e -x

# Download URLhaus database
wget https://urlhaus.abuse.ch/downloads/text/ -O ../src/URLhaus.txt

# Download Cisco Umbrella 1 Million
wget https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip -O top-1m.csv.zip

cp ../src/exclude.txt .

## Clean up URLhaus.txt
cat ../src/URLhaus.txt | \
# Convert DOS to Unix line ending
dos2unix | \
# Remove comment
sed '/^#/ d' | \
# Remove http(s)://
cut -f 3 -d '/' | \
# Remove port number
cut -f 1 -d ':' | \
# Remove www
# Only matches domains that start with www
# Not examplewww.com
sed 's/^www\.//g' | \
# Sort and remove duplicates
sort -u > urlhaus.txt
