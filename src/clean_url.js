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

const safeLinks = [
  'safelinks\\.protection\\.outlook\\.com',
  '\\.protection\\.sophos\\.com',
  'linkprotect\\.cudasvc\\.com'
]

const deSafelink = (urlStr) => {
  let url = new URL(urlStr)

  // O365 Safelinks
  if (url.hostname.endsWith('safelinks.protection.outlook.com')) {
    url = new URL(url.searchParams.get('url'))
  }

  // Sophos
  if (url.hostname.endsWith('.protection.sophos.com')) {
    url = new URL(`http://${url.searchParams.get('d')}`)
  }

  // Barracuda
  if (url.hostname.endsWith('linkprotect.cudasvc.com')) {
    url = new URL(url.searchParams.get('a'))
  }

  if (url.hostname.match(new RegExp(safeLinks.join('|')))) {
    return deSafelink(url.href)
  }

  return url.href
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
      const url = new URL(deSafelink(cleanHost(line)))

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
