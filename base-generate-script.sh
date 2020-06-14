#!/bin/bash


login() {
  gcloud -q auth activate-service-account "${account_name}" --key-file "${key_file}" || exit 1
  gcloud -q config set project "${project_id}" || exit 1
}

usage() {
  local this_script
  this_script=$(basename "$0")
  local supported
  supported=$(grep "^\s*create_deletion_code " "${this_script}" | cut -d " " -f2 | tr '\n' ', ' | rev | cut -c 2- | rev)
  supported="${supported} storage,functions"

  cat <<EOD >&2
Usage:
./generate-script -a my-service-account@myproject.iam.gserviceaccount.com -k project-viewer-credentials.json -p  my-project [-f filter-expression]"
  -a service account
  -k filename for credentials file
  -p project id or account
  -f filter expression. Run gcloud topics filter for documentation. This filter is not supported on Google Storage buckets except for single key=value  label filters (in the form "labels.key=val").
  -b to generate a deletion script that runs all commands asynchronously (potentially concurrently). This will speed up deletion.
  -h help

You can direct output to create your deletion script, as for example by  suffixing
       > deletion-script.sh  && chmod a+x deletion-script.sh

Resources from these APIs are supported: ${supported}
EOD
  exit 1
}

create_deletion_code() {
  local gcloud_component=$1
  local resource_types=$2

  # shellcheck disable=SC2207
  local resource_types_array=($(echo "$resource_types" | tr ' ' '\n'))
  for resource_type in "${resource_types_array[@]}"; do
    echo >&2 "Listing ${gcloud_component} ${resource_type}"
    local resources
    resources="$(gcloud -q "${gcloud_component}" "${resource_type}" list --filter "${filter}" --uri)"
    local resources_array=()
    # shellcheck disable=SC2207
    resources_array=($(echo "$resources" | tr ' ' '\n'))
    if [ -n "${resources}" ]; then
      echo >&2 "Listed ${#resources_array[@]} ${gcloud_component} ${resource_type}"
    fi
    local resource
    for resource in "${resources_array[@]}"; do
      echo "gcloud ${gcloud_component} ${resource_type} delete -q ${resource} $async_ampersand"
    done
  done
}

create_cloud_functions_deletion_code() {
  echo >&2 "Listing cloud functions"
  local funcs
  funcs=$(gcloud -q functions list --filter "${filter}" --format="table[no-heading](name)")
  # shellcheck disable=SC2207
  local funcs_array=($(echo "${funcs}" | tr ' ' '\n'))
  if [ -n "${funcs}" ]; then
    echo >&2 "Listed ${#funcs_array[@]} functions"
  fi
  local func
  for func in "${funcs_array[@]}"; do
    echo "gcloud functions delete -q ${func}"
  done
}
function get_labeled_bucket() {
  # list all of the buckets for the current project
  for bucket in $(gsutil ls); do
    # find the one with your label
    if gsutil label get "${bucket}" | grep -q '"key": "value"'; then
      # and return its name
      echo "${bucket}"
    fi
  done
}

create_unfiltered_bucket_deletion_code() {
  local buckets
  buckets="$(gsutil ls)"
  # shellcheck disable=SC2207
  local buckets_array=($(echo "${buckets}" | tr ' ' '\n'))
  if [ -n "${buckets}" ]; then
    echo >&2 "Listed ${#buckets_array[@]} buckets"
  fi

  local bucket
  for bucket in "${buckets_array[@]}"; do
    echo "gsutil rm -r ${bucket}" # $bucket variable is in the form gs://bucketname
  done
}

create_bucket_deletion_code_filtered_by_label() {
  local filter_1 key val bucket label_match, counter
  # At this point, we know that first 7 characters are "labels.". We remove these.
  filter_1=$(echo "${filter}" | tr -d '[:space:]' | cut -c 8-)
  key=$(echo "$filter_1" | cut -d "=" -f 1)
  # shellcheck disable=SC2086
  val=$(echo $filter_1 | cut -d "=" -f 2)
  echo >&2 "Will filter buckets by the label filter ${key}: ${val}"
  counter=0
  for bucket in $(gsutil ls); do
    label_match=$(gsutil label get "${bucket}" | grep \""${key}\": \"${val}\"")
    if [ -n "${label_match}" ]; then
      counter=$((counter + 1))

      echo "gsutil rm -r ${bucket}"
    fi
  done
  echo "Listed ${counter} buckets"
}

create_bucket_deletion_code() {
  echo >&2 "Listing buckets"

  local single_keyval counter
  if [ -n "${filter}" ]; then
    single_keyval=$(echo "${filter}" | tr -d '[:space:]' | grep -E "^labels\.[a-z][a-z0-9_-]*=[a-z][a-z0-9_-]*$")
    if [ -n "$single_keyval" ]; then
      create_bucket_deletion_code_filtered_by_label
      return
    else
      echo >&2 "Warning: \"${filter}\" is not a simple single-key label equality filter; will ignore the  filter for storage buckets."
    fi
  fi
  # We do the following if there is no filter, or a filter that is not a single key equalty label filter
  create_unfiltered_bucket_deletion_code
}

while getopts 'k:p:a:f:b' OPTION; do
  case "$OPTION" in
  k)

    key_file="$OPTARG"
    ;;
  p)
    project_id="$OPTARG"
    ;;
  a)
    account_name="$OPTARG"
    ;;
  f)
    filter="$OPTARG"
    ;;
  b)
    async_ampersand="&"
    ;;
  ?)
    usage
    ;;
  esac
done

if [[ -z ${account_name} || (-z ${key_file} || -z ${project_id}) ]]; then
  usage
fi

login

create_deletion_code container clusters
create_cloud_functions_deletion_code
create_deletion_code pubsub "subscriptions topics snapshots"
compute_resource_types="instances backend-services firewall-rules forwarding-rules health-checks http-health-checks https-health-checks instance-groups instance-templates routers routes target-pools target-tcp-proxies networks"
create_deletion_code compute "${compute_resource_types}"
create_deletion_code sql instances
create_deletion_code app "services versions instances firewall-rules" # services covers versions and instances but we want to generate a list for human review
create_bucket_deletion_code
