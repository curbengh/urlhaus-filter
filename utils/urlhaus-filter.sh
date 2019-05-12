#!/bin/sh

## Merge malware-domains.txt malware-url-top-domains.txt,
## and append a header to instruct uBO to grab the filter daily.

CURRENT_TIME="$(date -R -u)"
FIRST_LINE="! Title: abuse.ch URLhaus Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Expires: 1 day (update frequency)"
FOURTH_LINE="! Repo: https://gitlab.com/curben/urlhaus-filter"
FIFTH_LINE="! License: https://creativecommons.org/publicdomain/zero/1.0/"
SIXTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE\n$SIXTH_LINE"

cat malware-domains.txt malware-url-top-domains.txt | \
# Sort alphabetically
sort | \
# Append header comment to the filter list
sed '1 i\'"$COMMENT"'' > ../urlhaus-filter.txt
