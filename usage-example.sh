#!/usr/bin/env bash

# In this example, we send the output of the generation script into a new deletion script,
# and set access permissions for this script to be executable.

./generate-script.sh -b -a project-viewer@my-project.iam.gserviceaccount.com \
  -k project-viewer-credentials.json -p my-project -f "labels.key1=val1" \
  >deletion-script.sh && chmod a+x deletion-script.sh
