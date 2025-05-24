import { createWriteStream } from 'node:fs'
import { open } from 'node:fs/promises'

const domains = await open('malware-domains-online.txt')
const urls = await open('malware-url-top-domains-raw-online.txt')

const snort2 = createWriteStream('../public/urlhaus-filter-snort2-online.rules', {
  encoding: 'utf8',
  flags: 'a'
})
const snort3 = createWriteStream('../public/urlhaus-filter-snort3-online.rules', {
  encoding: 'utf8',
  flags: 'a'
})
const suricata = createWriteStream('../public/urlhaus-filter-suricata-online.rules', {
  encoding: 'utf8',
  flags: 'a'
})
const suricataSni = createWriteStream('../public/urlhaus-filter-suricata-sni-online.rules', {
  encoding: 'utf8',
  flags: 'a'
})
const splunk = createWriteStream('../public/urlhaus-filter-splunk-online.csv', {
  encoding: 'utf8',
  flags: 'a'
})

let sid = 100000001

for await (const domain of domains.readLines()) {
  snort2.write(`alert tcp $HOME_NET any -> $EXTERNAL_NET [80,443] (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; content:"GET"; http_method; content:"${domain}"; content:"Host"; http_header; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  snort3.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; http_header:field host; content:"${domain}",nocase; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  suricata.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; http.method; content:"GET"; http.host; content:"${domain}"; classtype:trojan-activity; sid:${sid} rev:1;)\n`)
  suricataSni.write(`alert tls $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; tls.sni; bsize:32; content:"${domain}"; fast_pattern; classtype:trojan-activity; sid:${sid} rev:1;)\n`)
  splunk.write(`"${domain}","","urlhaus-filter malicious website detected","${process.env.CURRENT_TIME}"\n`)

  sid++
}

suricataSni.close()

for await (const line of urls.readLines()) {
  if (!URL.canParse(`http://${line}`)) {
    console.error(`Invalid URL: ${line}`)
    continue
  }

  const url = new URL(`http://${line}`)
  const { hostname, pathname, search } = url
  const pathEscape = `${pathname}${search}`.replaceAll(';', '\\;')
  const path = pathname + search

  snort2.write(`alert tcp $HOME_NET any -> $EXTERNAL_NET [80,443] (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; content:"GET"; http_method; content:"${pathEscape.substring(0, 2048)}"; http_uri; nocase; content:"${hostname}"; content:"Host"; http_header; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  snort3.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; http_header:field host; content:"${hostname}",nocase; http_uri; content:"${pathEscape}",nocase; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  suricata.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; http.method; content:"GET"; http.uri; content:"${pathEscape}"; endswith; nocase; http.host; content:"${hostname}"; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  splunk.write(`"${hostname}","${path}","urlhaus-filter malicious website detected","${process.env.CURRENT_TIME}"\n`)

  sid++
}

snort2.close()
snort3.close()
suricata.close()
splunk.close()
