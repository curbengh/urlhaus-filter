# URLhaus Malicious URL Blocklist

This [uBO](https://github.com/gorhill/uBlock/)-compatible filter list is based on the database dump (CSV) of Abuse.sh [URLhaus](https://urlhaus.abuse.ch/).

## Subscribe

Filter is updated once a day.

Click the link to subscribe to this filter:
[abp:subscribe?location=https://gitlab.com/curben/urlhaus/raw/master/urlhaus-filter.txt&amp;title=abuse.ch URLhaus Malicious URL Blocklist](abp%3Asubscribe%3Flocation%3Dhttps%3A%2F%2Fgitlab.com%2Fcurben%2Furlhaus%2Fraw%2Fmaster%2Furlhaus-filter.txt%26amp%3Btitle%3Dabuse.ch%20URLhaus%20Malicious%20URL%20Blocklist)

Or import the following URL into uBO:
https://gitlab.com/curben/urlhaus/raw/master/urlhaus-filter.txt

## Description

Following URL categories are removed from the database dump:
* Offline URL
* Well-known host or false positives (see [exclude.txt](exclude.txt))

Database dump is saved as URLhaus.csv, processed by script.sh and output as urlhaus-filter.txt.

## Note

Please report any false positive, especially if the domain is one of the Alexa 10M.

This filter **only** accepts malware URLs from [URLhaus](https://urlhaus.abuse.ch/).

Please report malware URL to the upstream maintainer through https://urlhaus.abuse.ch/api/#submit.

This repo is not endorsed by Abuse.sh.

## FAQ

- Can you add this *very-bad-url.com* to the filter?
	+ No, please report to the [upstream](https://urlhaus.abuse.ch/api/#submit).

- Why do you need to clone the repo again in your CI?
	+ GitLab Runner clone/fetch the repo using HTTPS method by default ([log](https://gitlab.com/curben/urlhaus/-/jobs/105979394)). This method requires deploy *token* which is *read-only* (cannot push).
	+ Deploy *key* has write access but cannot be used with the HTTPS method, hence, the workaround to clone using SSH.
	+ See issue [#20567](https://gitlab.com/gitlab-org/gitlab-ce/issues/20567) and [#20845](https://gitlab.com/gitlab-org/gitlab-ce/issues/20845).