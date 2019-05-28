#!/bin/sh

set -e -x

## Parse popular domains from URLhaus

cat urlhaus-domains.txt | \
# grep match whole line
grep -Fx -f top-1m-well-known.txt > urlhaus-top-domains.txt
