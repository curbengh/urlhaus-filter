#!/bin/sh

# works best on busybox ash

set -efx -o pipefail

alias curl="curl -L"
alias rm="rm -rf"

## Use GNU grep, busybox grep is too slow
. "/etc/os-release"
DISTRO="$ID"

if [ -z "$(grep --help | grep 'GNU')" ]; then
  if [ "$DISTRO" = "alpine" ]; then
    echo "Please install GNU grep 'apk add grep'"
    exit 1
  fi
  alias grep="/usr/bin/grep"
fi


## Fallback to busybox dos2unix
if ! command -v dos2unix &> /dev/null
then
  alias dos2unix="busybox dos2unix"
fi


## Create a temporary working folder
mkdir -p "tmp/"
cd "tmp/"


## Prepare datasets
curl "https://urlhaus.abuse.ch/downloads/csv/" -o "urlhaus.zip"
curl "https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip" -o "top-1m-umbrella.zip"
curl "https://tranco-list.eu/top-1m.csv.zip" -o "top-1m-tranco.zip"

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
  curl "$DATASET_URL" -o "cf/top-1m-radar.zip"

  ## Parse the Radar 1 Million
  unzip -p "cf/top-1m-radar.zip" | \
  dos2unix | \
  tr "[:upper:]" "[:lower:]" | \
  grep -F "." | \
  sed "s/^www\.//g" | \
  sort -u > "top-1m-radar.txt"
fi

cp -f "../src/exclude.txt" "."

## Prepare URLhaus.csv
unzip -p "urlhaus.zip" | \
# Convert DOS to Unix line ending
dos2unix | \
tr "[:upper:]" "[:lower:]" | \
# Remove comment
sed "/^#/d" > "URLhaus.csv"

## Parse URLs
cat "URLhaus.csv" | \
cut -f 6 -d '"' | \
cut -f 3- -d "/" | \
# Domain must have at least a 'dot'
grep -F "." | \
# Remove invalid protocol, see #32
sed -E "s/^(ttps:\/\/|https:\/|http\/)//g" | \
# Remove www.
sed "s/^www\.//g" | \
sort -u > "urlhaus.txt"

## Parse domain and IP address only
cat "urlhaus.txt" | \
cut -f 1 -d "/" | \
# Remove port
cut -f 1 -d ":" | \
# Remove invalid domains, see #15
grep -vF "??" | \
cut -f 1 -d "?" | \
sort -u > "urlhaus-domains.txt"

## Parse online URLs only
cat "URLhaus.csv" | \
grep '"online"' | \
cut -f 6 -d '"' | \
cut -f 3- -d "/" | \
sed "s/^www\.//g" | \
sort -u > "urlhaus-online.txt"

cat "urlhaus-online.txt" | \
cut -f 1 -d "/" | \
cut -f 1 -d ":" | \
grep -vF "??" | \
cut -f 1 -d "?" | \
sort -u > "urlhaus-domains-online.txt"


## Parse the Umbrella 1 Million
unzip -p "top-1m-umbrella.zip" | \
dos2unix | \
tr "[:upper:]" "[:lower:]" | \
# Parse domains only
cut -f 2 -d "," | \
grep -F "." | \
# Remove www.
sed "s/^www\.//g" | \
sort -u > "top-1m-umbrella.txt"

## Parse the Tranco 1 Million
unzip -p "top-1m-tranco.zip" | \
dos2unix | \
tr "[:upper:]" "[:lower:]" | \
# Parse domains only
cut -f 2 -d "," | \
grep -F "." | \
# Remove www.
sed "s/^www\.//g" | \
sort -u > "top-1m-tranco.txt"

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
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-url-top-domains.txt"

cat "urlhaus-online.txt" | \
grep -F -f "urlhaus-top-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-url-top-domains-online.txt"

cat "urlhaus-online.txt" | \
grep -F -f "urlhaus-top-domains.txt" > "malware-url-top-domains-raw-online.txt"


## Merge malware domains and URLs
CURRENT_TIME="$(date -R -u)"
FIRST_LINE="! Title: Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Expires: 1 day (update frequency)"
FOURTH_LINE="! Homepage: https://gitlab.com/malware-filter/urlhaus-filter"
FIFTH_LINE="! License: https://gitlab.com/malware-filter/urlhaus-filter#license"
SIXTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT_ABP="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE\n$SIXTH_LINE"

mkdir -p "../public/"

cat "malware-domains.txt" "malware-url-top-domains.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' > "../public/urlhaus-filter.txt"

cat "malware-domains-online.txt" "malware-url-top-domains-online.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" > "../public/urlhaus-filter-online.txt"


# Adguard Home (#19, #22)
cat "malware-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/^/g" > "malware-domains-adguard-home.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/g" | \
sed "s/$/^/g" > "malware-domains-online-adguard-home.txt"

cat "malware-domains-adguard-home.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Blocklist/Blocklist (AdGuard Home)/" > "../public/urlhaus-filter-agh.txt"

cat "malware-domains-online-adguard-home.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (AdGuard Home)/" > "../public/urlhaus-filter-agh-online.txt"


# Adguard browser extension
cat "malware-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-domains-adguard.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-domains-online-adguard.txt"

cat "malware-domains-adguard.txt" "malware-url-top-domains.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Blocklist/Blocklist (AdGuard)/" > "../public/urlhaus-filter-ag.txt"

cat "malware-domains-online-adguard.txt" "malware-url-top-domains-online.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (AdGuard)/" > "../public/urlhaus-filter-ag-online.txt"


# Vivaldi
cat "malware-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$document/g" > "malware-domains-vivaldi.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$document/g" > "malware-domains-online-vivaldi.txt"

cat "malware-domains-vivaldi.txt" "malware-url-top-domains.txt" | \
sed "s/\$all$/\$document/g" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Blocklist/Blocklist (Vivaldi)/" > "../public/urlhaus-filter-vivaldi.txt"

cat "malware-domains-online-vivaldi.txt" "malware-url-top-domains-online.txt" | \
sed "s/\$all$/\$document/g" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (Vivaldi)/" > "../public/urlhaus-filter-vivaldi-online.txt"


## Domains-only blocklist
# awk + head is a workaround for sed prepend
COMMENT=$(printf "$COMMENT_ABP" | sed "s/^!/#/g" | sed "1s/URL/Domains/" | awk '{printf "%s\\n", $0}' | head -c -2)
COMMENT_ONLINE=$(printf "$COMMENT" | sed "1s/Malicious/Online Malicious/" | awk '{printf "%s\\n", $0}' | head -c -2)

cat "malware-domains.txt" | \
sort | \
sed '1 i\'"$COMMENT"'' > "../public/urlhaus-filter-domains.txt"

cat "malware-domains-online.txt" | \
sort | \
sed '1 i\'"$COMMENT_ONLINE"'' > "../public/urlhaus-filter-domains-online.txt"


## Hosts only
cat "malware-domains.txt" | \
sort | \
# Remove IPv4 address
grep -vE "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" > "malware-hosts.txt"

cat "malware-domains-online.txt" | \
sort | \
# Remove IPv4 address
grep -vE "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" > "malware-hosts-online.txt"


## Hosts file blocklist
cat "malware-hosts.txt" | \
sed "s/^/0.0.0.0 /g" | \
# Re-insert comment
sed '1 i\'"$COMMENT"'' | \
sed "1s/Domains/Hosts/" > "../public/urlhaus-filter-hosts.txt"

cat "malware-hosts-online.txt" | \
sed "s/^/0.0.0.0 /g" | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Domains/Hosts/" > "../public/urlhaus-filter-hosts-online.txt"


## Dnsmasq-compatible blocklist
cat "malware-hosts.txt" | \
sed "s/^/address=\//g" | \
sed "s/$/\/0.0.0.0/g" | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Blocklist/dnsmasq Blocklist/" > "../public/urlhaus-filter-dnsmasq.conf"

cat "malware-hosts-online.txt" | \
sed "s/^/address=\//g" | \
sed "s/$/\/0.0.0.0/g" | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Blocklist/dnsmasq Blocklist/" > "../public/urlhaus-filter-dnsmasq-online.conf"


## BIND-compatible blocklist
cat "malware-hosts.txt" | \
sed 's/^/zone "/g' | \
sed 's/$/" { type master; notify no; file "null.zone.file"; };/g' | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Blocklist/BIND Blocklist/" > "../public/urlhaus-filter-bind.conf"

cat "malware-hosts-online.txt" | \
sed 's/^/zone "/g' | \
sed 's/$/" { type master; notify no; file "null.zone.file"; };/g' | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Blocklist/BIND Blocklist/" > "../public/urlhaus-filter-bind-online.conf"


## DNS Response Policy Zone (RPZ)
CURRENT_UNIX_TIME="$(date +%s)"
RPZ_SYNTAX="\n\$TTL 30\n@ IN SOA rpz.malware-filter.gitlab.io. hostmaster.rpz.malware-filter.gitlab.io. $CURRENT_UNIX_TIME 86400 3600 604800 30\n NS localhost.\n"

cat "malware-hosts.txt" | \
sed "s/$/ CNAME ./g" | \
sed '1 i\'"$RPZ_SYNTAX"'' | \
sed '1 i\'"$COMMENT"'' | \
sed "s/^#/;/g" | \
sed "1s/Blocklist/RPZ Blocklist/" > "../public/urlhaus-filter-rpz.conf"

cat "malware-hosts-online.txt" | \
sed "s/$/ CNAME ./g" | \
sed '1 i\'"$RPZ_SYNTAX"'' | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "s/^#/;/g" | \
sed "1s/Blocklist/RPZ Blocklist/" > "../public/urlhaus-filter-rpz-online.conf"


## Unbound-compatible blocklist
cat "malware-hosts.txt" | \
sed 's/^/local-zone: "/g' | \
sed 's/$/" always_nxdomain/g' | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Blocklist/Unbound Blocklist/" > "../public/urlhaus-filter-unbound.conf"

cat "malware-hosts-online.txt" | \
sed 's/^/local-zone: "/g' | \
sed 's/$/" always_nxdomain/g' | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Blocklist/Unbound Blocklist/" > "../public/urlhaus-filter-unbound-online.conf"


## dnscrypt-proxy blocklists
# name-based
cat "malware-hosts.txt" | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Domains/Names/" > "../public/urlhaus-filter-dnscrypt-blocked-names.txt"

cat "malware-hosts-online.txt" | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Domains/Names/" > "../public/urlhaus-filter-dnscrypt-blocked-names-online.txt"

## IPv4-based
cat "malware-domains.txt" | \
sort | \
grep -E "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Domains/IPs/" > "../public/urlhaus-filter-dnscrypt-blocked-ips.txt"

cat "malware-domains-online.txt" | \
sort | \
grep -E "^([0-9]{1,3}[\.]){3}[0-9]{1,3}$" | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Domains/IPs/" > "../public/urlhaus-filter-dnscrypt-blocked-ips-online.txt"


## Temporarily disable command print
set +x


# Snort, Suricata, Splunk
rm "../public/urlhaus-filter-snort2-online.rules" \
  "../public/urlhaus-filter-snort3-online.rules" \
  "../public/urlhaus-filter-suricata-online.rules" \
  "../public/urlhaus-filter-splunk-online.csv"

SID="100000001"
while read DOMAIN; do
  SN_RULE="alert tcp \$HOME_NET any -> \$EXTERNAL_NET [80,443] (msg:\"urlhaus-filter malicious website detected\"; flow:established,from_client; content:\"GET\"; http_method; content:\"$DOMAIN\"; content:\"Host\"; http_header; classtype:trojan-activity; sid:$SID; rev:1;)"

  SN3_RULE="alert http \$HOME_NET any -> \$EXTERNAL_NET any (msg:\"urlhaus-filter malicious website detected\"; http_header:field host; content:\"$DOMAIN\",nocase; classtype:trojan-activity; sid:$SID; rev:1;)"

  SR_RULE="alert http \$HOME_NET any -> \$EXTERNAL_NET any (msg:\"urlhaus-filter malicious website detected\"; flow:established,from_client; http.method; content:\"GET\"; http.host; content:\"$DOMAIN\"; classtype:trojan-activity; sid:$SID; rev:1;)"

  SP_RULE="\"$DOMAIN\",\"\",\"urlhaus-filter malicious website detected\",\"$CURRENT_TIME\""

  echo "$SN_RULE" >> "../public/urlhaus-filter-snort2-online.rules"
  echo "$SN3_RULE" >> "../public/urlhaus-filter-snort3-online.rules"
  echo "$SR_RULE" >> "../public/urlhaus-filter-suricata-online.rules"
  echo "$SP_RULE" >> "../public/urlhaus-filter-splunk-online.csv"

  SID=$(( $SID + 1 ))
done < "malware-domains-online.txt"

while read URL; do
  DOMAIN=$(echo "$URL" | cut -d"/" -f1)
  # escape ";"
  PATHNAME=$(echo "$URL" | sed -e "s/^$DOMAIN//" -e "s/;/\\\;/g")

  # Snort2 only supports <=2047 characters of `content`
  SN_RULE="alert tcp \$HOME_NET any -> \$EXTERNAL_NET [80,443] (msg:\"urlhaus-filter malicious website detected\"; flow:established,from_client; content:\"GET\"; http_method; content:\"$(echo $PATHNAME | cut -c -2047)\"; http_uri; nocase; content:\"$DOMAIN\"; content:\"Host\"; http_header; classtype:trojan-activity; sid:$SID; rev:1;)"

  SN3_RULE="alert http \$HOME_NET any -> \$EXTERNAL_NET any (msg:\"urlhaus-filter malicious website detected\"; http_header:field host; content:\"$DOMAIN\",nocase; http_uri; content:\"$PATHNAME\",nocase; classtype:trojan-activity; sid:$SID; rev:1;)"

  SR_RULE="alert http \$HOME_NET any -> \$EXTERNAL_NET any (msg:\"urlhaus-filter malicious website detected\"; flow:established,from_client; http.method; content:\"GET\"; http.uri; content:\"$PATHNAME\"; endswith; nocase; http.host; content:\"$DOMAIN\"; classtype:trojan-activity; sid:$SID; rev:1;)"

  PATHNAME=$(echo "$URL" | sed "s/^$DOMAIN//")

  SP_RULE="\"$DOMAIN\",\"$PATHNAME\",\"urlhaus-filter malicious website detected\",\"$CURRENT_TIME\""

  echo "$SN_RULE" >> "../public/urlhaus-filter-snort2-online.rules"
  echo "$SN3_RULE" >> "../public/urlhaus-filter-snort3-online.rules"
  echo "$SR_RULE" >> "../public/urlhaus-filter-suricata-online.rules"
  echo "$SP_RULE" >> "../public/urlhaus-filter-splunk-online.csv"

  SID=$(( $SID + 1 ))
done < "malware-url-top-domains-raw-online.txt"

## Re-enable command print
set -x

sed -i '1 i\'"$COMMENT_ONLINE"'' "../public/urlhaus-filter-snort2-online.rules"
sed -i "1s/Domains Blocklist/URL Snort2 Ruleset/" "../public/urlhaus-filter-snort2-online.rules"

sed -i '1 i\'"$COMMENT_ONLINE"'' "../public/urlhaus-filter-snort3-online.rules"
sed -i "1s/Domains Blocklist/URL Snort3 Ruleset/" "../public/urlhaus-filter-snort3-online.rules"

sed -i '1 i\'"$COMMENT_ONLINE"'' "../public/urlhaus-filter-suricata-online.rules"
sed -i "1s/Domains Blocklist/URL Suricata Ruleset/" "../public/urlhaus-filter-suricata-online.rules"

sed -i -e '1 i\'"$COMMENT_ONLINE"' ' -e '1 i\"host","path","message","updated"' "../public/urlhaus-filter-splunk-online.csv"
sed -i "1s/Domains Blocklist/URL Splunk Lookup/" "../public/urlhaus-filter-splunk-online.csv"


## IE blocklist
COMMENT_IE="msFilterList\n$COMMENT\n: Expires=1\n#"
COMMENT_ONLINE_IE="msFilterList\n$COMMENT_ONLINE\n: Expires=1\n#"

cat "malware-hosts.txt" | \
sed "s/^/-d /g" | \
sed '1 i\'"$COMMENT_IE"'' | \
sed "2s/Domains Blocklist/Hosts Blocklist (IE)/" > "../public/urlhaus-filter.tpl"

cat "malware-hosts-online.txt" | \
sed "s/^/-d /g" | \
sed '1 i\'"$COMMENT_ONLINE_IE"'' | \
sed "2s/Domains Blocklist/Hosts Blocklist (IE)/" > "../public/urlhaus-filter-online.tpl"


## Clean up artifacts
rm "URLhaus.csv" "top-1m-umbrella.zip" "top-1m-umbrella.txt" "top-1m-tranco.txt" "cf/" "top-1m-radar.txt"


cd ../
