# URLhaus Malicious URL Blocklist

This [uBO](https://github.com/gorhill/uBlock/)-compatible filter list is based on the database dump (CSV) of Abuse.sh [URLhaus](https://urlhaus.abuse.ch/).

## Subscribe

Filter is updated once a day.

Import the following URL into uBO to subcribe:

https://gitlab.com/curben/urlhaus/raw/master/urlhaus-filter.txt

## Description

Following URL categories are removed from the database dump:

- Offline URL
- Well-known host ([top-1m.txt](top-1m.txt)) or false positives ([exclude.txt](exclude.txt))

Database dump is saved as [URLhaus.csv](URLhaus.csv), processed by [script.sh](script.sh) and output as [urlhaus-filter.txt](urlhaus-filter.txt).

## Note

Please report any false positive.

This filter **only** accepts malware URLs from [URLhaus](https://urlhaus.abuse.ch/).

Please report malware URL to the upstream maintainer through https://urlhaus.abuse.ch/api/#submit.

This repo is not endorsed by Abuse.sh.

## FAQ

- Can you add this *very-bad-url.com* to the filter?
	+ No, please report to the [upstream](https://urlhaus.abuse.ch/api/#submit).

- Why don't you use the URLhaus "Plain-Text URL List"?
	+ It doesn't show the status (online/offline) of a URL.

- Why do you need to clone the repo again in your CI? I thought CI already fetch the repo by default?
	+ GitLab Runner clone/fetch the repo using HTTPS method by default ([log](https://gitlab.com/curben/urlhaus/-/jobs/105979394)). This method requires deploy *token* which is *read-only* (cannot push).
	+ Deploy *key* has write access but cannot be used with the HTTPS method, hence, the workaround to clone using SSH.
	+ See issue [#20567](https://gitlab.com/gitlab-org/gitlab-ce/issues/20567) and [#20845](https://gitlab.com/gitlab-org/gitlab-ce/issues/20845).
