'use strict'

// for deployment outside of GitLab CI, e.g. Cloudflare Pages and Netlify

const { stream: gotStream } = require('got')
const unzip = require('extract-zip')
const { join } = require('path')
const { mkdir } = require('fs/promises')
const { createWriteStream } = require('fs')
const { pipeline } = require('stream/promises')

const rootPath = join(__dirname, '..')
const tmpPath = join(rootPath, 'tmp')
const publicPath = join(rootPath, 'public')
const zipPath = join(tmpPath, 'artifacts.zip')
const artifactsUrl = 'https://nightly.link/curbengh/urlhaus-filter/workflows/pages/main/public.zip'
const ghMirror = 'https://gitlab.com/curben/urlhaus-filter/-/jobs/artifacts/main/download?job=pages'

const f = async () => {
  let isMirror = false

  await mkdir(tmpPath, { recursive: true })

  console.log(`Downloading artifacts.zip from "${artifactsUrl}"`)
  try {
    await pipeline(
      gotStream(artifactsUrl),
      createWriteStream(zipPath)
    )
  } catch ({ message }) {
    console.error(JSON.stringify({
      error: message,
      link: artifactsUrl
    }))

    console.log(`Downloading artifacts.zip from "${ghMirror}"`)
    isMirror = true

    try {
      await pipeline(
        gotStream(ghMirror),
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
