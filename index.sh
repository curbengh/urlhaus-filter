#!/bin/sh

# -e: Fail the whole script if any command fails
# -x: Display running command
set -e -x

# Create a temporary working folder
# -p: No error if existing
mkdir -p tmp/ && cd tmp/

# Download URLhaus database and Umbrella Top 1M
sh ../utils/prerequisites.sh

# Process the Umbrella Top 1M
sh ../utils/umbrella-top-1m.sh

# Parse popular domains that also appear in URLhaus
sh ../utils/urlhaus-top-domains.sh

# Parse domains from URLhaus excluding popular domains
sh ../utils/malware-domains.sh

# Parse malware URLs from popular domains
sh ../utils/malware-url-top-domains.sh

# Merge malware domains and URLs
sh ../utils/urlhaus-filter.sh

# Commit the changes
sh ../utils/commit.sh

# Clean up the working folder
cd ../ && rm -r tmp/
