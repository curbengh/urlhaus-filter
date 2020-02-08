#!/bin/sh

set -efux -o pipefail

## Commit the filter update

## GitLab CI does not permit shell variable in .gitlab-ci.yml.
## This file is a workaround for that.

CURRENT_TIME="$(date -R -u)"
git commit -a -m "Filter updated: $CURRENT_TIME"
