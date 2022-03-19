#!/bin/sh

ARTIFACT_STATUS=$(curl -sSIL "https://gitlab.com/curben/urlhaus-filter/-/jobs/artifacts/main/download?job=pages" | grep -F "HTTP/2 200")
PIPELINE_STATUS=$(curl -sSL "https://gitlab.com/curben/urlhaus-filter/badges/main/pipeline.svg" | grep -F "failed")
GITLAB_STATUS="up"

if [ -z "$ARTIFACT_STATUS" ] || [ -n "$PIPELINE_STATUS" ]; then
  GITLAB_STATUS="down"
fi

echo "GITLAB_STATUS=$GITLAB_STATUS" >> "$GITHUB_ENV"
