# URLhaus Malicious URL Blocklist

A block list of malicious URLs that are being used for malware distribution. This [uBO](https://github.com/gorhill/uBlock/)-compatible filter list is based on the **Plain-Text URL List** and **Database dump (CSV)** of Abuse.ch [URLhaus](https://urlhaus.abuse.ch/).

## Subscribe

Filter is updated twice a day.

Import the following URL into uBO to subscribe:

- https://gitlab.com/curben/urlhaus-filter/raw/master/urlhaus-filter.txt

Mirrors:

- https://glcdn.githack.com/curben/urlhaus-filter/raw/master/urlhaus-filter.txt
- https://cdn.staticaly.com/gl/curben/urlhaus-filter/raw/master/urlhaus-filter.txt

<br />
Lite version (online urls only):

- https://gitlab.com/curben/urlhaus-filter/raw/master/urlhaus-filter-online.txt

Mirrors:

- https://glcdn.githack.com/curben/urlhaus-filter/raw/master/urlhaus-filter-online.txt
- https://cdn.staticaly.com/gl/curben/urlhaus-filter/raw/master/urlhaus-filter-online.txt


**Note:** Lite version is ~95% smaller by excluding offline urls only. The status of urls is determined by the upstream Abuse.ch. However, the test is not 100% accurate and some malicious urls that are otherwise accessible may be missed. If bandwidth (1.5MB/day) is not a constraint, I recommend the regular version.

*PS: While regular version contains roughly 65K filters, uBO can [easily handle](https://github.com/uBlockOrigin/uBlock-issues/issues/338#issuecomment-452843669) half a million filters.*

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

Note that some of the software above are host-based only, meaning it cannot block malware URLs hosted by well-known domains (e.g. amazonaws.com, docs.google.com, dropbox.com). For best compatibility, use uBO or its fork NanoAdblocker.

## Issues

Report any false positive by creating an [issue](https://gitlab.com/curben/urlhaus-filter/issues) or [merge request](https://gitlab.com/curben/urlhaus-filter/merge_requests)

This filter **only** accepts malware URLs from [URLhaus](https://urlhaus.abuse.ch/).

Please report new malware URL to the upstream maintainer through https://urlhaus.abuse.ch/api/#submit.

This repo is not endorsed by Abuse.ch.

## Cloning

Since the filter is updated frequently, cloning the repo would become slower over time as the revision grows.

Use shallow clone to get the recent revisions only. Getting the last five revisions should be sufficient for a valid MR.

`git clone --depth 5 https://gitlab.com/curben/urlhaus-filter.git`

## License

[Creative Commons Zero v1.0 Universal](LICENSE.md)

## FAQ

See [wiki](https://gitlab.com/curben/urlhaus-filter/wikis/FAQ).
