# URLhaus Malicious URL Blocklist

A block list of malicious URLs that are being used for malware distribution. This [uBO](https://github.com/gorhill/uBlock/)-compatible filter list is based on the database dump (CSV) of Abuse.sh [URLhaus](https://urlhaus.abuse.ch/).

## Subscribe

Filter is updated twice a day.

Import the following URL into uBO to subscribe:

- https://gitlab.com/curben/urlhaus-filter/raw/master/urlhaus-filter.txt

<br />
Mirrors:

- https://glcdn.githack.com/curben/urlhaus-filter/raw/master/urlhaus-filter.txt
- https://cdn.staticaly.com/gl/curben/urlhaus-filter/raw/master/urlhaus-filter.txt

## Description

Following URL categories are removed from the database dump:

- Offline URLs
- Well-known domains ([top-1m.txt](src/top-1m.txt)) (using [Umbrella Popularity List](https://s3-us-west-1.amazonaws.com/umbrella-static/index.html))
- False positives ([exclude.txt](src/exclude.txt))

Database dump is saved as [URLhaus.csv](src/URLhaus.csv), get processed by [script.sh](utils/script.sh) and output as [urlhaus-filter.txt](urlhaus-filter.txt).

## Compatibility

This filter is only tested with uBO. [FilterLists](https://filterlists.com/) shows it is compatible with the following software:

- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)
- [Google Hit Hider](https://www.jeffersonscher.com/gm/google-hit-hider/)
- [hostsmgr](https://www.henrypp.org/product/hostsmgr)
- [NanoAdblocker](https://github.com/NanoAdblocker/NanoCore)
- [Personal Blocklist](https://addons.mozilla.org/firefox/addon/personal-blocklist/)
- [personalDNSfilter](https://zenz-solutions.de/personaldnsfilter)
- [Pi-hole](https://pi-hole.net/)
- [Samsung Knox](https://www.samsungknox.com/)
- [uMatrix](https://github.com/gorhill/uMatrix)

## Issues

Please report any false positive.

This filter **only** accepts malware URLs from [URLhaus](https://urlhaus.abuse.ch/).

Please report malware URL to the upstream maintainer through https://urlhaus.abuse.ch/api/#submit.

This repo is not endorsed by Abuse.sh.

## Cloning

Since the filter is updated frequently, cloning the repo would become slower over time as the revision grows.

Use shallow clone to get the recent revisions only. Getting the last five revisions is sufficient for a valid MR.

`git clone --depth 5 https://gitlab.com/curben/urlhaus-filter.git`

## License

[Creative Commons Zero v1.0 Universal](LICENSE.md)

## FAQ

See [wiki](https://gitlab.com/curben/urlhaus-filter/wikis/FAQ).
