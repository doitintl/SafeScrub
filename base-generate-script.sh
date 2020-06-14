#!/bin/bash
set -x

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
  -f filter expression. Run gcloud topics filter for documentation. This filter is not supported on Google Storage.

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
    resources="$(gcloud -q "${gcloud_component}" "${resource_type}" list --filter "${filter}" --uri) "
    local resources_array=()
    # shellcheck disable=SC2207
    resources_array=($(echo "$resources" | tr ' ' '\n'))
    local resource
    for resource in "${resources_array[@]}"; do
      echo "gcloud ${gcloud_component} ${resource_type} delete -q ${resource}"
    done
  done
}

create_cloud_functions_deletion_code() {
  echo >&2 "Listing Functions"
  local funcs
  funcs=$(gcloud -q functions list --filter "${filter}" --format="table[no-heading](name)" )
  # shellcheck disable=SC2207
  local funcs_array=($(echo "${funcs}" | tr ' ' '\n'))
  local func
  for func in "${funcs_array[@]}"; do
    echo "gcloud functions delete -q ${func}"
  done
}

create_bucket_deletion_code() {
  echo >&2 "Listing Buckets"
  local buckets
  buckets="$(gsutil ls)"
  # shellcheck disable=SC2207
  local buckets_array=($(echo "${buckets}" | tr ' ' '\n'))
  local bucket
  for bucket in "${buckets_array[@]}"; do
    echo "gsutil rm -r ${bucket}" # $bucket variable is in the form gs://bucketname
  done
}

while getopts 'k:p:a:f:' OPTION; do
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
create_bucket_deletion_code
create_cloud_functions_deletion_code

create_deletion_code pubsub "subscriptions topics snapshots"

compute_resource_types="addresses backend-services firewall-rules forwarding-rules health-checks http-health-checks https-health-checks instance-groups instance-templates instances networks routers routes target-pools target-tcp-proxies"
create_deletion_code compute "${compute_resource_types}"

create_deletion_code sql instances
create_deletion_code app "services versions instances firewall-rules"  # services covers versions and instances but we want to generate a list for human review
