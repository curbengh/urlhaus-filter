#!/bin/sh

mkdir tmp/
cd tmp/

sh ../utils/prerequisites.sh
sh ../utils/umbrella-top-1m.sh
sh ../utils/malware-domains.sh
sh ../utils/urlhaus-top-domains.sh
sh ../utils/malware-url-top-domains.sh
sh ../utils/urlhaus-filter.sh
sh ../utils/commit.sh

cd ../
rm -r tmp/
