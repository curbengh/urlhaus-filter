'use strict'

// for deployment outside of GitLab CI, e.g. Cloudflare Pages and Netlify

import unzip from 'extract-zip'
import { dirname, join } from 'node:path'
import { mkdir } from 'node:fs/promises'
import { createWriteStream } from 'node:fs'
import { pipeline } from 'node:stream/promises'
import { fileURLToPath } from 'node:url'
import { Readable } from 'node:stream'

const __dirname = dirname(fileURLToPath(import.meta.url))
const rootPath = join(__dirname, '..')
const tmpPath = join(rootPath, 'tmp')
const publicPath = join(rootPath, 'public')
const zipPath = join(tmpPath, 'artifacts.zip')
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
  let isMirror = false

  await mkdir(tmpPath, { recursive: true })

  console.log(`Downloading artifacts.zip from "${artifactsUrl}"`)
  try {
    await pipeline(
      Readable.fromWeb((await fetch(artifactsUrl)).body),
      createWriteStream(zipPath)
    )
    await pipelineStatus(pipelineUrl)
  } catch ({ message }) {
    console.error(JSON.stringify({
      error: message,
      link: artifactsUrl
    }))

    console.log(`Downloading artifacts.zip from "${ghMirror}"`)
    isMirror = true

    try {
      await pipeline(
        Readable.fromWeb((await fetch(ghMirror)).body),
        createWriteStream(zipPath)
      )
    } catch ({ message }) {
      throw new Error(JSON.stringify({
        error: message,
        link: ghMirror
      }))
    }
  }

  console.log('Extracting artifacts.zip...')
  if (isMirror === false) {
    await unzip(zipPath, { dir: rootPath })
  } else {
    await mkdir(publicPath, { recursive: true })
    await unzip(zipPath, { dir: publicPath })
  }
}

f()
