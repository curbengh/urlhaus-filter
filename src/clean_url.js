'use strict'

import { createInterface } from 'node:readline'

const cleanHost = (hostname) => {
  return hostname
  // Remove invalid protocol, see #32
  .replace(/^(https?:\/\/)(?:ttps:\/\/|https:\/|http\/)/, '$1')
  .replace(/^(https?:\/\/)?www\./, '$1')
}

// nodejs does not percent-encode ^ yet
// https://github.com/nodejs/node/issues/57313
// Applies to path, exclude query string
const caretPath = (pathname) => {
  if (!pathname.includes('?')) return pathname.replaceAll('^', '%5E')

  const pathArray = pathname.split('?')
  const path = pathArray[0].replaceAll('^', '%5E')
  const search = pathArray.slice(1).join('?')

  return `${path}?${search}`
}

for await (const line of createInterface({ input: process.stdin, terminal: false })) {
  // parse hostname from url
  if (process.argv[2] === 'hostname') {
    if (URL.canParse(`http://${line}`)) {
      const url = new URL(`http://${line}`)

      console.log(url.hostname)
    } else {
      const hostname = line
        // host
        .split('/')[0]
        // exclude credential
        .replace(/.*@(.+)/, '$1')
        // exclude port
        .replace(/:\d+$/, '')
        // #2
        .split('?')[0]

      console.log(hostname)
    }
  } else {
    // Skip invalid domains, see #15
    if (line.split('/')[2].includes('??')) continue

    if (URL.canParse(line)) {
      let url = new URL(cleanHost(line))

      // Decode O365 Safelinks
      // https://support.microsoft.com/en-us/office/advanced-outlook-com-security-for-microsoft-365-subscribers-882d2243-eab9-4545-a58a-b36fee4a46e2
      if (url.hostname.endsWith('safelinks.protection.outlook.com')) {
        url = new URL(url.searchParams.get('url'))
      }

      url.host = cleanHost(url.host)

      // nodejs does not percent-encode ^ yet
      // https://github.com/nodejs/node/issues/57313
      url.pathname = caretPath(url.pathname)
      const outUrl = `${url.host}${url.pathname}${url.search}`
        // remove trailing slash from domain except path
        .replace(/(^[^/]*)\/+$/, '$1')

      console.log(outUrl)
    } else {
      const outUrl = caretPath(cleanHost(line
        // remove protocol
        .split('/').slice(2).join('/')))
        // url encode space
        .replaceAll(' ', '%20')
        .replace(/(^[^/]*)\/+$/, '$1')

      console.log(outUrl)
    }
  }
}
