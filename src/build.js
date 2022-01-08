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
const zipPath = join(tmpPath, 'artifacts.zip')
const artifactsUrl = 'https://gitlab.com/curben/urlhaus-filter/-/jobs/artifacts/main/download?job=pages'

const f = async () => {
  await mkdir(tmpPath, { recursive: true })

  console.log(`Downloading artifacts.zip from "${artifactsUrl}"`)
  await pipeline(
    gotStream(artifactsUrl),
    createWriteStream(zipPath)
  )

  console.log('Extracting artifacts.zip...')
  await unzip(zipPath, { dir: rootPath })
}

f()
