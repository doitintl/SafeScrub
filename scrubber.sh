#!/bin/bash

trap "exit" INT
rm  -f stderror.txt
set -x
function login() {
  gcloud auth activate-service-account "${account_name}" --key-file "${key_file}" || exit 1
  gcloud config set project "${project_id}" || exit 1
}

function usage() {
  echo "script usage: $(basename $0) -k key-file-for-service-account.json -a account-name-from-key-file -p project_id" >&2
  exit 1
}

function create_deletion_code() {
  gcloud_component=$1
  resource_types_list=$2
  get_uri=$3
  if [ "true" = ${get_uri} ]; then
    get_uri_option="--uri"
  else
    get_uri_option=""
  fi

  # shellcheck disable=SC2207
  resource_types_array=($(echo "$resource_types_list" | tr ' ' '\n'))
  for resource_type in "${resource_types_array[@]}"; do
    resource_list="$(gcloud  ${gcloud_component} ${resource_type}  list ${get_uri_option} 2>> error.txt)"
    [ -z "${resource_list}" ] && continue
    resource_array=()
    echo $resource_list | while IFS="" read -r line; do resource_array+=("$line"); done
    for resource_uri in "${resource_array[@]}"; do
      echo "gcloud ${gcloud_component} ${resource_type} delete -q ${resource_uri}"
    done

  done
}

while getopts 'k:p:a:' OPTION; do
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
    ?)
      usage
      ;;
  esac
done

if [[ -z ${account_name} || (  -z ${key_file}  ||  -z ${project_id} ) ]]; then
  usage
fi

#TODO filter out firewalls/default and networks/    default

login
echo AAA
compute_resource_types="firewall-rules" #TODO forwarding-rule addresses routers routes target-tcp-proxies backend-services instance-groups managed instance-templates instances target-pools health-checks http-health-checks https-health-checks networks subnets networks"
echo BBB
create_deletion_code compute ${compute_resource_types} true
exit 1
echo 111
create_deletion_code container clusters false
echo 222
create_deletion_code sql instances true
echo 333
create_deletion_code app instances true
echo 444
# TODO gsutil list



echo 666
