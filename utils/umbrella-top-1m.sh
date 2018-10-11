#!/bin/sh

# Download the Cisco Umbrella 1 Million
# More info:
# https://s3-us-west-1.amazonaws.com/umbrella-static/index.html

# Download the list
wget https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip -O top-1m.csv.zip

# Decompress the zip and write output to stdout
unzip -p top-1m.csv.zip | \
# Convert DOS to Unix line ending
dos2unix | \
# Parse domains only
cut -f 2 -d ',' | \
# Remove www
# Only matches domains that start with www
# Not examplewww.com
sed ':a;N;$!ba;s/\nwww\./\n/g' | \
# Remove duplicates
sort -u > ../src/top-1m.txt

# Remove downloaded zip file
rm top-1m.csv.zip
