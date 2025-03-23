#!/bin/sh

if ! (set -o pipefail 2>/dev/null); then
  # dash does not support pipefail
  set -efx
else
  set -efx -o pipefail
fi

# bash does not expand alias by default for non-interactive script
if [ -n "$BASH_VERSION" ]; then
  shopt -s expand_aliases
fi

alias curl="curl -L"
alias rm="rm -rf"

## Use GNU grep, busybox grep is not as performant
DISTRO=""
if [ -f "/etc/os-release" ]; then
  . "/etc/os-release"
  DISTRO="$ID"
fi

check_grep() {
  if [ -z "$(grep --help | grep 'GNU')" ]; then
    if [ -x "/usr/bin/grep" ]; then
      alias grep="/usr/bin/grep"
      check_grep
    else
      if [ "$DISTRO" = "alpine" ]; then
        echo "Please install GNU grep 'apk add grep'"
      else
        echo "GNU grep not found"
      fi
      exit 1
    fi
  fi
}
check_grep

if ! command -v dos2unix &> /dev/null
then
  if command -v busybox &> /dev/null
  then
    alias dos2unix="busybox dos2unix"
  else
    echo "dos2unix or busybox not found"
    exit 1
  fi
fi

if command -v unzip &> /dev/null
then
  alias unzip="unzip -p"
elif command -v busybox &> /dev/null
then
  alias unzip="busybox unzip -p"
elif command -v bsdunzip &> /dev/null
then
  alias unzip="bsdunzip -p"
else
  echo "unzip not found"
  exit 1
fi

## Create a temporary working folder
rm "tmp/"
mkdir -p "tmp/"
cd "tmp/"


## Prepare datasets
curl "https://urlhaus.abuse.ch/downloads/csv/" -o "urlhaus.zip"
curl "https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip" -o "top-1m-umbrella.zip"
curl "https://tranco-list.eu/download/daily/top-1m.csv.zip" -o "top-1m-tranco.zip"

## Cloudflare Radar
if [ -n "$CF_API" ]; then
  mkdir -p "cf/"
  # Get the latest domain ranking buckets
  curl -X GET "https://api.cloudflare.com/client/v4/radar/datasets?limit=5&offset=0&datasetType=RANKING_BUCKET&format=json" \
    -H "Authorization: Bearer $CF_API" -o "cf/datasets.json"
  # Get the top 1m bucket's dataset ID
  DATASET_ID=$(jq ".result.datasets[] | select(.meta.top==1000000) | .id" "cf/datasets.json")
  # Get the dataset download url
  curl --request POST \
    --url "https://api.cloudflare.com/client/v4/radar/datasets/download" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $CF_API" \
    --data "{ \"datasetId\": $DATASET_ID }" \
    -o "cf/dataset-url.json"
  DATASET_URL=$(jq ".result.dataset.url" "cf/dataset-url.json" | sed 's/"//g')
  curl "$DATASET_URL" -o "cf/top-1m-radar.csv"

  ## Parse the Radar 1 Million
  cat "cf/top-1m-radar.csv" | \
  dos2unix | \
  tr "[:upper:]" "[:lower:]" | \
  grep -F "." | \
  sed "s/^www\.//" | \
  sort -u > "top-1m-radar.txt"
fi

cp -f "../src/exclude.txt" "."

## Prepare URLhaus.csv
unzip "urlhaus.zip" | \
# Convert DOS to Unix line ending
dos2unix | \
tr "[:upper:]" "[:lower:]" | \
# Remove comment
sed "/^#/d" > "URLhaus.csv"

## Parse URLs
cat "URLhaus.csv" | \
cut -f 6 -d '"' | \
node "../src/clean_url.js" | \
sort -u > "urlhaus.txt"

## Parse domain and IP address only
cat "urlhaus.txt" | \
node "../src/clean_url.js" hostname | \
sort -u > "urlhaus-domains.txt"

## Parse online URLs only
cat "URLhaus.csv" | \
grep -F '"online"' | \
cut -f 6 -d '"' | \
node "../src/clean_url.js" | \
sort -u > "urlhaus-online.txt"

cat "urlhaus-online.txt" | \
node "../src/clean_url.js" hostname | \
sort -u > "urlhaus-domains-online.txt"


## Parse the Umbrella 1 Million
unzip "top-1m-umbrella.zip" | \
dos2unix | \
tr "[:upper:]" "[:lower:]" | \
# Parse domains only
cut -f 2 -d "," | \
grep -F "." | \
# Remove www.
sed "s/^www\.//" | \
sort -u > "top-1m-umbrella.txt"

## Parse the Tranco 1 Million
if [ -n "$(file 'top-1m-tranco.zip' | grep 'Zip archive data')" ]; then
  unzip "top-1m-tranco.zip" | \
  dos2unix | \
  tr "[:upper:]" "[:lower:]" | \
  # Parse domains only
  cut -f 2 -d "," | \
  grep -F "." | \
  # Remove www.
  sed "s/^www\.//" | \
  sort -u > "top-1m-tranco.txt"
else
  # tranco has unreliable download
  echo "top-1m-tranco.zip is not a zip, skipping it..."
  touch "top-1m-tranco.txt"
fi

# Merge Umbrella and self-maintained top domains
cat "top-1m-umbrella.txt" "top-1m-tranco.txt" "exclude.txt" | \
sort -u > "top-1m-well-known.txt"

if [ -n "$CF_API" ] && [ -f "top-1m-radar.txt" ]; then
  cat "top-1m-radar.txt" >> "top-1m-well-known.txt"
  # sort in-place
  sort "top-1m-well-known.txt" -u -o "top-1m-well-known.txt"
fi

## Parse popular domains from URLhaus
cat "urlhaus-domains.txt" | \
# grep match whole line
grep -Fx -f "top-1m-well-known.txt" > "urlhaus-top-domains.txt"


## Parse domains from URLhaus excluding popular domains
cat "urlhaus-domains.txt" | \
grep -F -vf "urlhaus-top-domains.txt" | \
# Remove blank lines
sed "/^$/d" > "malware-domains.txt"

cat "urlhaus-domains-online.txt" | \
grep -F -vf "urlhaus-top-domains.txt" | \
sed "/^$/d" > "malware-domains-online.txt"

## Parse malware URLs from popular domains
cat "urlhaus.txt" | \
grep -F -f "urlhaus-top-domains.txt" | \
sed "s/^/||/" | \
sed 's/$/^$all/' > "malware-url-top-domains.txt"

cat "urlhaus-online.txt" | \
grep -F -f "urlhaus-top-domains.txt" | \
sed "s/^/||/" | \
sed 's/$/^$all/' > "malware-url-top-domains-online.txt"

cat "urlhaus-online.txt" | \
grep -F -f "urlhaus-top-domains.txt" > "malware-url-top-domains-raw-online.txt"


## Merge malware domains and URLs
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FIRST_LINE="! Title: Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Expires: 1 day (update frequency)"
FOURTH_LINE="! Homepage: https://gitlab.com/malware-filter/urlhaus-filter"
FIFTH_LINE="! License: https://gitlab.com/malware-filter/urlhaus-filter#license"
SIXTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT_ABP="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE\n$SIXTH_LINE"

mkdir -p "../public/"

cat "malware-domains.txt" "malware-url-top-domains.txt" | \
sed "1i $COMMENT_ABP" > "../public/urlhaus-filter.txt"

cat "malware-domains-online.txt" "malware-url-top-domains-online.txt" | \
sed "1i $COMMENT_ABP" | \
sed "1s/Malicious/Online Malicious/" > "../public/urlhaus-filter-online.txt"


# Adguard Home (#19, #22)
cat "malware-domains.txt" | \
sed "s/^/||/" | \
sed "s/$/^/" | \
sort -u > "malware-domains-adguard-home.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/" | \
sed "s/$/^/" > "malware-domains-online-adguard-home.txt"

cat "malware-domains-adguard-home.txt" | \
sed "1i $COMMENT_ABP" | \
sed "1s/Blocklist/Blocklist (AdGuard Home)/" > "../public/urlhaus-filter-agh.txt"

cat "malware-domains-online-adguard-home.txt" | \
sed "1i $COMMENT_ABP" | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (AdGuard Home)/" > "../public/urlhaus-filter-agh-online.txt"


# Adguard browser extension
cat "malware-domains.txt" | \
sed "s/^/||/" | \
sed 's/$/^$all/' > "malware-domains-adguard.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/" | \
sed 's/$/^$all/' > "malware-domains-online-adguard.txt"

cat "malware-domains-adguard.txt" "malware-url-top-domains.txt" | \
sed "1i $COMMENT_ABP" | \
sed "1s/Blocklist/Blocklist (AdGuard)/" > "../public/urlhaus-filter-ag.txt"

cat "malware-domains-online-adguard.txt" "malware-url-top-domains-online.txt" | \
sed "1i $COMMENT_ABP" | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (AdGuard)/" > "../public/urlhaus-filter-ag-online.txt"


# Vivaldi
cat "malware-domains.txt" | \
sed "s/^/||/" | \
sed 's/$/^$document/' > "malware-domains-vivaldi.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/" | \
sed 's/$/^$document/' > "malware-domains-online-vivaldi.txt"

cat "malware-domains-vivaldi.txt" "malware-url-top-domains.txt" | \
sed 's/\$all$/$document/' | \
sed "1i $COMMENT_ABP" | \
sed "1s/Blocklist/Blocklist (Vivaldi)/" > "../public/urlhaus-filter-vivaldi.txt"

cat "malware-domains-online-vivaldi.txt" "malware-url-top-domains-online.txt" | \
sed 's/\$all$/$document/' | \
sed "1i $COMMENT_ABP" | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (Vivaldi)/" > "../public/urlhaus-filter-vivaldi-online.txt"


## Domains-only blocklist
# awk + head is a workaround for sed prepend
COMMENT=$(printf "$COMMENT_ABP" | sed "s/^!/#/" | sed "1s/URL/Domains/" | awk '{printf "%s\\n", $0}' | head -c -2)
COMMENT_ONLINE=$(printf "$COMMENT" | sed "1s/Malicious/Online Malicious/" | awk '{printf "%s\\n", $0}' | head -c -2)

cat "malware-domains.txt" | \
sed "1i $COMMENT" > "../public/urlhaus-filter-domains.txt"

cat "malware-domains-online.txt" | \
sed "1i $COMMENT_ONLINE" > "../public/urlhaus-filter-domains-online.txt"


## Hosts only
cat "malware-domains.txt" | \
# exclude IPv4
grep -vE "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" | \
# exclude IPv6
grep -vE "^\[" > "malware-hosts.txt"

cat "malware-domains-online.txt" | \
grep -vE "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" | \
grep -vE "^\[" > "malware-hosts-online.txt"


## Hosts file blocklist
cat "malware-hosts.txt" | \
sed "s/^/0.0.0.0 /" | \
# Re-insert comment
sed "1i $COMMENT" | \
sed "1s/Domains/Hosts/" > "../public/urlhaus-filter-hosts.txt"

cat "malware-hosts-online.txt" | \
sed "s/^/0.0.0.0 /" | \
sed "1i $COMMENT_ONLINE" | \
sed "1s/Domains/Hosts/" > "../public/urlhaus-filter-hosts-online.txt"


## Dnsmasq-compatible blocklist
cat "malware-hosts.txt" | \
sed "s/^/address=\//" | \
sed "s/$/\/0.0.0.0/" | \
sed "1i $COMMENT" | \
sed "1s/Blocklist/dnsmasq Blocklist/" > "../public/urlhaus-filter-dnsmasq.conf"

cat "malware-hosts-online.txt" | \
sed "s/^/address=\//" | \
sed "s/$/\/0.0.0.0/" | \
sed "1i $COMMENT_ONLINE" | \
sed "1s/Blocklist/dnsmasq Blocklist/" > "../public/urlhaus-filter-dnsmasq-online.conf"


## BIND-compatible blocklist
cat "malware-hosts.txt" | \
sed 's/^/zone "/' | \
sed 's/$/" { type master; notify no; file "null.zone.file"; };/' | \
sed "1i $COMMENT" | \
sed "1s/Blocklist/BIND Blocklist/" > "../public/urlhaus-filter-bind.conf"

cat "malware-hosts-online.txt" | \
sed 's/^/zone "/' | \
sed 's/$/" { type master; notify no; file "null.zone.file"; };/' | \
sed "1i $COMMENT_ONLINE" | \
sed "1s/Blocklist/BIND Blocklist/" > "../public/urlhaus-filter-bind-online.conf"


## DNS Response Policy Zone (RPZ)
CURRENT_UNIX_TIME="$(date +%s)"
RPZ_SYNTAX="\n\$TTL 30\n@ IN SOA localhost. root.localhost. $CURRENT_UNIX_TIME 86400 3600 604800 30\n NS localhost.\n"

cat "malware-hosts.txt" | \
sed "s/$/ CNAME ./" | \
sed '1 i\'"$RPZ_SYNTAX"'' | \
sed "1i $COMMENT" | \
sed "s/^#/;/" | \
sed "1s/Blocklist/RPZ Blocklist/" > "../public/urlhaus-filter-rpz.conf"

cat "malware-hosts-online.txt" | \
sed "s/$/ CNAME ./" | \
sed '1 i\'"$RPZ_SYNTAX"'' | \
sed "1i $COMMENT_ONLINE" | \
sed "s/^#/;/" | \
sed "1s/Blocklist/RPZ Blocklist/" > "../public/urlhaus-filter-rpz-online.conf"


## Unbound-compatible blocklist
cat "malware-hosts.txt" | \
sed 's/^/local-zone: "/' | \
sed 's/$/" always_nxdomain/' | \
sed "1i $COMMENT" | \
sed "1s/Blocklist/Unbound Blocklist/" > "../public/urlhaus-filter-unbound.conf"

cat "malware-hosts-online.txt" | \
sed 's/^/local-zone: "/' | \
sed 's/$/" always_nxdomain/' | \
sed "1i $COMMENT_ONLINE" | \
sed "1s/Blocklist/Unbound Blocklist/" > "../public/urlhaus-filter-unbound-online.conf"


## dnscrypt-proxy blocklists
# name-based
cat "malware-hosts.txt" | \
sed "1i $COMMENT" | \
sed "1s/Domains/Names/" > "../public/urlhaus-filter-dnscrypt-blocked-names.txt"

cat "malware-hosts-online.txt" | \
sed "1i $COMMENT_ONLINE" | \
sed "1s/Domains/Names/" > "../public/urlhaus-filter-dnscrypt-blocked-names-online.txt"

# IPv4/6
if grep -Eq "^(([0-9]{1,3}[\.]){3}[0-9]{1,3}$|\[)" "phishing-notop-domains.txt"; then
  cat "malware-domains.txt" | \
  grep -E "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" | \
  sed -r "s/\[|\]//g" | \
  sed "1i $COMMENT" | \
  sed "1s/Domains/IPs/" > "../public/urlhaus-filter-dnscrypt-blocked-ips.txt"

  cat "malware-domains-online.txt" | \
  grep -E "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" | \
  sed -r "s/\[|\]//g" | \
  sed "1i $COMMENT_ONLINE" | \
  sed "1s/Domains/IPs/" > "../public/urlhaus-filter-dnscrypt-blocked-ips-online.txt"
else
  echo | \
  sed "1i $COMMENT" | \
  sed "1s/Domains/IPs/" > "../public/urlhaus-filter-dnscrypt-blocked-ips.txt"

  echo | \
  sed "1i $COMMENT_ONLINE" | \
  sed "1s/Domains/IPs/" > "../public/urlhaus-filter-dnscrypt-blocked-ips-online.txt"
fi

## Wildcard subdomain
cat "malware-domains.txt" | \
sed "s/^/*./" | \
sed "1i $COMMENT" | \
sed "1s/Blocklist/Wildcard Asterisk Blocklist/" > "../public/urlhaus-filter-wildcard.txt"

cat "malware-domains-online.txt" | \
sed "s/^/*./" | \
sed "1i $COMMENT" | \
sed "1s/Blocklist/Wildcard Asterisk Blocklist/" > "../public/urlhaus-filter-wildcard-online.txt"


# Snort, Suricata, Splunk
rm "../public/urlhaus-filter-snort2-online.rules" \
  "../public/urlhaus-filter-snort3-online.rules" \
  "../public/urlhaus-filter-suricata-online.rules" \
  "../public/urlhaus-filter-splunk-online.csv"

export CURRENT_TIME
node "../src/ids.js"

sed -i "1i $COMMENT_ONLINE" "../public/urlhaus-filter-snort2-online.rules"
sed -i "1s/Domains Blocklist/URL Snort2 Ruleset/" "../public/urlhaus-filter-snort2-online.rules"

sed -i "1i $COMMENT_ONLINE" "../public/urlhaus-filter-snort3-online.rules"
sed -i "1s/Domains Blocklist/URL Snort3 Ruleset/" "../public/urlhaus-filter-snort3-online.rules"

sed -i "1i $COMMENT_ONLINE" "../public/urlhaus-filter-suricata-online.rules"
sed -i "1s/Domains Blocklist/URL Suricata Ruleset/" "../public/urlhaus-filter-suricata-online.rules"

sed -i -e "1i $COMMENT_ONLINE" -e '1i "host","path","message","updated"' "../public/urlhaus-filter-splunk-online.csv"
sed -i "1s/Domains Blocklist/URL Splunk Lookup/" "../public/urlhaus-filter-splunk-online.csv"


## IE blocklist
COMMENT_IE="msFilterList\n$COMMENT\n: Expires=1\n#"
COMMENT_ONLINE_IE="msFilterList\n$COMMENT_ONLINE\n: Expires=1\n#"

cat "malware-hosts.txt" | \
sed "s/^/-d /" | \
sed "1i $COMMENT_IE" | \
sed "2s/Domains Blocklist/Hosts Blocklist (IE)/" > "../public/urlhaus-filter.tpl"

cat "malware-hosts-online.txt" | \
sed "s/^/-d /" | \
sed "1i $COMMENT_ONLINE_IE" | \
sed "2s/Domains Blocklist/Hosts Blocklist (IE)/" > "../public/urlhaus-filter-online.tpl"


## Clean up artifacts
rm "URLhaus.csv" "top-1m-umbrella.zip" "top-1m-umbrella.txt" "top-1m-tranco.txt" "cf/" "top-1m-radar.txt"


cd ../
