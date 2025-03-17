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
const splunk = createWriteStream('../public/urlhaus-filter-splunk-online.csv', {
  encoding: 'utf8',
  flags: 'a'
})

let sid = 100000001

for await (const domain of domains.readLines()) {
  snort2.write(`alert tcp $HOME_NET any -> $EXTERNAL_NET [80,443] (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; content:"GET"; http_method; content:"${domain}"; content:"Host"; http_header; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  snort3.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; http_header:field host; content:"${domain}",nocase; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  suricata.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; http.method; content:"GET"; http.host; content:"${domain}"; classtype:trojan-activity; sid:${sid} rev:1;)\n`)
  splunk.write(`"${domain}","","urlhaus-filter malicious website detected","${process.env.CURRENT_TIME}"\n`)

  sid++
}

for await (const line of urls.readLines()) {
  const url = new URL(`http://${line}`)
  const { hostname } = url
  let pathname = url.pathname.replace(';', '\\;')
  snort2.write(`alert tcp $HOME_NET any -> $EXTERNAL_NET [80,443] (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; content:"GET"; http_method; content:"${pathname.substring(0, 2048)}"; http_uri; nocase; content:"${hostname}"; content:"Host"; http_header; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  snort3.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; http_header:field host; content:"${hostname}",nocase; http_uri; content:"${pathname}",nocase; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  suricata.write(`alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"urlhaus-filter malicious website detected"; flow:established,from_client; http.method; content:"GET"; http.uri; content:"${pathname}"; endswith; nocase; http.host; content:"${hostname}"; classtype:trojan-activity; sid:${sid}; rev:1;)\n`)
  pathname = url.pathname
  splunk.write(`"${hostname}","${pathname}","urlhaus-filter malicious website detected","${process.env.CURRENT_TIME}"\n`)

  sid++
}

snort2.close()
snort3.close()
suricata.close()
splunk.close()
