#!/bin/bash

# Calls the base script, and also
# 1. Directs the output through a filter so that items in  "exclusions.txt" are not in the ultimate output script
# 2. On exit, reverts the logged-in user to what it was before the script is run.
function revert_authentication() {
  gcloud config set account "${original_account}"
  gcloud config set project "${original_project}"
}

trap "revert_authentication" INT

original_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
original_project=$(gcloud config get-value project)
exclusions_file=exclusions.txt
# If exclusions.txt file is empty, add a comment. This is to prevent grep -v -f from failing the whole script
grep -q '[^[:space:]]' < "${exclusions_file}" || echo "# No excluded resources" > ${exclusions_file}

./base-gen-deletion-script.sh "$@" | grep -v -f ${exclusions_file}

revert_authentication
