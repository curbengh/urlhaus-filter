#!/bin/sh

# Download URLhaus database
wget https://urlhaus.abuse.ch/downloads/csv/ -O ../src/URLhaus.csv

# Download Cisco Umbrella 1 Million
wget https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip -O top-1m.csv.zip

cp ../src/URLhaus.csv .
cp ../src/exclude.txt .
