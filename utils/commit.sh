#!/bin/sh

# Commit the filter update

CURRENT_TIME="$(date -R -u)"
git commit -a -m "Filter updated: $CURRENT_TIME"
