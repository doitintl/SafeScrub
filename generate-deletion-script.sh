#!/usr/bin/env bash

exclusions_file=exclusions.txt
temp_exclusions_file="${exclusions_file}.tmp"

# Calls the base script, and also
# 1. Directs the output through a filter so that items in "exclusions.txt" are not in the ultimate output script
# 2. On exit, reverts the logged-in user to what it was before the script is run.
function revert() {
  [ -n "${original_account}" ] && gcloud config set account "${original_account}"
  [ -n "${original_project}" ] && gcloud config set project "${original_project}"
  rm ${temp_exclusions_file} ||true
}

trap "revert" EXIT

original_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
original_project=$(gcloud config get-value project)

# Remove blank lines from exclusions.txt, as these would cause everything to be excluded
grep -e "\S" ${exclusions_file} > ${temp_exclusions_file}

# If exclusions.txt file is empty, add a comment. This is to prevent grep -v -f from failing the whole script
grep -q '[^[:space:]]' <"${temp_exclusions_file}" || echo "# No excluded resources" >${temp_exclusions_file}

./base-gen-deletion-script.sh "$@" | grep -v -f ${temp_exclusions_file}

revert

