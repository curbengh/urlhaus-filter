#!/bin/sh

CURL_STATUS=$(curl -sSIL "https://gitlab.com/curben/urlhaus-filter/-/nonsense" | grep -F "HTTP/2 200")
GITLAB_STATUS="up"

if [ -z "$CURL_STATUS" ]; then
  GITLAB_STATUS="down"
fi

echo "GITLAB_STATUS=$GITLAB_STATUS" >> "$GITHUB_ENV"
