#!/bin/sh

# Download the Cisco Umbrella 1 Million
# More info:
# https://s3-us-west-1.amazonaws.com/umbrella-static/index.html

# Download the list
wget -O- http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip | \
# Unzip 
funzip | \
# Parse domains only
cut -f 2 -d ',' > ../src/top-1m.txt
