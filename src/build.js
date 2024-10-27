'use strict'

// for deployment outside of GitLab CI, e.g. Cloudflare Pages and Netlify

import { Extract } from 'unzipper'
import { dirname, join } from 'node:path'
import { mkdir } from 'node:fs/promises'
import { pipeline } from 'node:stream/promises'
import { fileURLToPath } from 'node:url'
import { Readable } from 'node:stream'

const __dirname = dirname(fileURLToPath(import.meta.url))
const rootPath = join(__dirname, '..')
const publicPath = join(rootPath, 'public')
const artifactsUrl = 'https://gitlab.com/malware-filter/urlhaus-filter/-/jobs/artifacts/main/download?job=pages'
const pipelineUrl = 'https://gitlab.com/malware-filter/urlhaus-filter/badges/main/pipeline.svg'
const ghMirror = 'https://nightly.link/curbengh/urlhaus-filter/workflows/pages/main/public.zip'

const pipelineStatus = async (url) => {
  console.log(`Checking pipeline from "${url}"`)
  try {
    const svg = await (await fetch(url)).text()
    if (svg.includes('failed')) throw new Error('last gitlab pipeline failed')
  } catch ({ message }) {
    throw new Error(message)
  }
}

const f = async () => {
  console.log(`Downloading artifacts.zip from "${artifactsUrl}"`)
  try {
    await pipeline(
      Readable.fromWeb((await fetch(artifactsUrl)).body),
      Extract({ path: rootPath })
    )
    await pipelineStatus(pipelineUrl)
  } catch ({ message }) {
    console.error(JSON.stringify({
      error: message,
      link: artifactsUrl
    }))

    console.log(`Downloading artifacts.zip from "${ghMirror}"`)

    await mkdir(publicPath, { recursive: true })

    try {
      await pipeline(
        Readable.fromWeb((await fetch(ghMirror)).body),
        Extract({ path: publicPath })
      )
    } catch ({ message }) {
      throw new Error(JSON.stringify({
        error: message,
        link: ghMirror
      }))
    }
  }
}

f()
