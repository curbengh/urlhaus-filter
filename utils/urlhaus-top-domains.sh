#!/bin/sh

set -e -x

## Parse popular domains from URLhaus

cat URLhaus.txt | \
# Exclude Umbrella Top 1M and well-known domains
# grep match whole line
grep -Fx -f top-1m-well-known.txt > urlhaus-top-domains.txt
