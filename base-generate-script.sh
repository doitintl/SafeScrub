#!/bin/bash

trap "exit" INT
function login() {
  gcloud -q auth activate-service-account "${account_name}" --key-file "${key_file}" || exit 1
  gcloud -q config set project "${project_id}" || exit 1
}

function usage() {
 >&2 echo "./generate-script -a my-service-account@myproject.iam.gserviceaccount.com -k project-viewer-credentials.json -p  my-project [-f filter-expression]"
>&2  echo "You can direct output to create your deletion script, as for example by  suffixing"
 >&2 echo "        > deletion-script.sh  && chmod a+x deletion-script.sh"
 >&2 printf "Resources from these APIs are supported: "
  this_script=$(basename "$0")
>&2  grep "^\s*create_deletion_code" "${this_script}" | cut -d " " -f2 | tr '\n' ', ' | rev | cut -c 2- | rev
  exit 1
}

function create_deletion_code() {
  gcloud_component=$1
  resource_types=$2
  get_uri=$3
  if [ "true" = "${get_uri}" ]; then
    uri_option="--uri"
  else
    uri_option=""
  fi

  # shellcheck disable=SC2207
  resource_types_array=($(echo "$resource_types" | tr ' ' '\n'))
  for resource_type in "${resource_types_array[@]}"; do
    >&2 echo "Listing ${gcloud_component} ${resource_type}"
    resource_uris="$(gcloud -q "${gcloud_component}" "${resource_type}" list --filter "${filter}" ${uri_option})"
    resource_uri_array=()
    # shellcheck disable=SC2207
    resource_uri_array=($(echo "$resource_uris" | tr ' ' '\n'))
    for resource_uri in "${resource_uri_array[@]}"; do
      echo "gcloud ${gcloud_component} ${resource_type} delete -q ${resource_uri}"
    done
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

create_deletion_code pubsub "subscriptions topics snapshots" true

compute_resource_types="addresses backend-services firewall-rules forwarding-rules health-checks http-health-checks https-health-checks instance-groups instance-templates instances networks routers routes target-pools target-tcp-proxies"
create_deletion_code compute "${compute_resource_types}" true

create_deletion_code container clusters false

create_deletion_code sql instances true
create_deletion_code app "services versions instances firewall-rules" true # services covers versions and instances but we want to generate a list for human review
# TODO gsutil list
# TODO (no resource type) create_deletion_code  functions "" true
