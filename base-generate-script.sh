#!/bin/bash

trap "exit" INT
set -x
function login() {
 gcloud -q auth activate-service-account "${account_name}" --key-file "${key_file}" || exit 1
 gcloud -q config set project "${project_id}" || exit 1
}

function usage() {
  echo "./generate-script -a my-service-account@myproject.iam.gserviceaccount.com -k project-viewer-credentials.json -p  my-project [-f filter-expression]"
  printf "Resources from these APIs are supported: "
  me=`basename "$0"`
  cat $me |grep "^\s*create_deletion_code" |cut -d " " -f2| tr '\n' ','| rev | cut -c 2- | rev
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

  filter_option=""
  if [ -n "${filter}" ]; then
     filter_option=${filter}
  fi

  # shellcheck disable=SC2207
  resource_types_array=($(echo "$resource_types" | tr ' ' '\n'))
  for resource_type in "${resource_types_array[@]}"; do
    resource_uris="$(gcloud -q "${gcloud_component}" "${resource_type}" list --filter "${filter_option}" ${uri_option} )"
    resource_uri_array=()
   # shellcheck disable=SC2207
   resource_uri_array=($(echo "$resource_uris" | tr ' ' '\n'))
   echo "AAAAAAAAAA WILL ITERATE OVER ALL " $resource_type
    for resource_uri in "${resource_uri_array[@]}"; do
      echo BBBBBBB $resource_type AAAAAAA $resource_uri
      echo "gcloud ${gcloud_component} ${resource_type} delete -q ${resource_uri}"
    done
    echo CCCCCCCCCCCCCCCCC "done with " $resource_type
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

compute_resource_types="firewall-rules forwarding-rules addresses routers routes target-tcp-proxies backend-services instance-groups managed instance-templates instances target-pools health-checks http-health-checks https-health-checks networks subnets networks"
create_deletion_code compute "${compute_resource_types}" true

create_deletion_code container clusters false

create_deletion_code sql instances true
create_deletion_code app "services versions instances firewall-rules" true # services covers versions and instances but we want to generate a list for human review
# TODO gsutil list

# TODO (no resource type create_deletion_code  functions "" true
