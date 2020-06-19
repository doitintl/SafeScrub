#!/usr/bin/env bash

# Generate the script and pipe it directly to bash for execution.
# This is dangerous, as it does not give you  chance to review the deletion commands
# before executing them.
./generate-deletion-script.sh \
  -k project-viewer-credentials.json \
  -p my-project \
  -f "labels.key1=val1" |
  bash
