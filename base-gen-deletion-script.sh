#!/bin/bash

login() {
  gcloud -q auth activate-service-account --key-file "${key_file}" || exit 1
  gcloud -q config set project "${project_id}" || exit 1
}

usage() {
  local this_script supported
  this_script=$(basename "$0")
  supported=$(grep "^\s*create_deletion_code " "${this_script}" | cut -d " " -f2 | tr '\n' ', ' | rev | cut -c 2- | rev | sed 's/,/, /g')
  supported="${supported}, storage"
  unsupported=$(grep "^# TODO Implement " base-gen-deletion-script.sh | cut -d " " -f4 | tr '\n' ', ' | rev | cut -c 2- | rev | sed 's/,/, /g')

  cat <<EOD >&2
Usage:
./generate-deletion-script -p  my-project [-a my-service-account@myproject.iam.gserviceaccount.com] [-k project-viewer-credentials.json] [-f filter-expression] [-b]"
  -p Project id or account
  -b (Optional.) Generate a deletion script that runs all commands asynchronously (in the background, i.e. concurrently). This will speed up deletion, but harder to monitor; and beware excess load from parallel operations.
  -f (Optional.) Filter expression. The default is no filtering. Run gcloud topics filter for documentation. This filter is not supported on Google Storage buckets except for single key=value  label filters (in the form "labels.key=val").
  -h Help. Prints this usage text.
  -k (Optional.) Filename for credentials file. The default value is project-viewer-credentials.json.

You can direct output to create your deletion script, as for example by  suffixing
       > deletion-script.sh  && chmod a+x deletion-script.sh

Resources from these services are supported: ${supported}
These services are not supported: ${unsupported}
EOD
  exit 1
}


# Generates the deletion code.
# Params are
# $1. gcloud_component (service, like compute or sql)
# $2. resource types as a space-seperated string, e.g. "instnaces routes addresses". Can be a single string or an empty string (no resource types, as in Cloud Fnctions)
# $3. if the URI is to be used in the deletion command; otherwise the resource name will be used.
create_deletion_code() {
  local resource_types_array resource_types gcloud_component resources resources_array resource
  gcloud_component=$1
  resource_types=$2
  use_uri=$3
  if [ "${use_uri}" == "true" ]; then
    identifier_option="--uri"
  else
    # shellcheck disable=SC2089
    identifier_option="--format=table[no-heading](name)"
  fi
  if [ -z "${resource_types}" ]; then
    resource_types_array=("")
  else
    # shellcheck disable=SC2207
    resource_types_array=($(echo "$resource_types" | tr ' ' '\n'))
  fi
  for resource_type in "${resource_types_array[@]}"; do
    echo >&2 "Listing ${gcloud_component} ${resource_type}"

    # No double-quote around ${resource} type because it may be an empty string and so a param that we wish to omit rather than treat as a param with value ""
    resources="$(gcloud -q "${gcloud_component}" ${resource_type} list --filter "${filter}" "${identifier_option}")"
    resources_array=()
    # shellcheck disable=SC2207
    resources_array=($(echo "$resources" | tr ' ' '\n'))
    if [ -n "${resources}" ]; then
      echo >&2 "Listed ${#resources_array[@]} ${gcloud_component} ${resource_type}"
    fi
    for resource in "${resources_array[@]}"; do
     # No double-quote around ${resource} type because it may be an empty string and so a param that we wish to omit rather than treat as a param with value ""
      echo "gcloud ${gcloud_component} ${resource_type} delete --project ${project_id} -q ${resource} ${async_ampersand}"
    done
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
  local buckets buckets_array bucket
  buckets="$(gsutil ls)"
  # shellcheck disable=SC2207
  buckets_array=($(echo "${buckets}" | tr ' ' '\n'))
  if [ -n "${buckets}" ]; then
    echo >&2 "Listed ${#buckets_array[@]} buckets"
  fi

  for bucket in "${buckets_array[@]}"; do
    echo "gsutil rm -r ${bucket} ${async_ampersand}" # $bucket variable is in the form gs://bucketname
  done
}

create_bucket_deletion_code_filtered_by_label() {
  local key_eq_val key val bucket label_match counter
  # At this point, we know that first 7 characters are "labels.". We remove these.
  key_eq_val=$(echo "${filter}" | cut -c 8-)
  key=$(echo "$key_eq_val" | cut -d "=" -f 1)
  # shellcheck disable=SC2086
  val=$(echo $key_eq_val | cut -d "=" -f 2)
  echo >&2 "Will filter buckets by the label filter ${key}: ${val}"
  counter=0
  for bucket in $(gsutil ls); do
    label_match=$(gsutil label get "${bucket}" | grep \""${key}\": \"${val}\"")
    if [ -n "${label_match}" ]; then
      counter=$((counter + 1))
      echo "gsutil rm -r ${bucket}"
    fi
  done
  echo >&2 "Listed ${counter} buckets"
}

create_bucket_deletion_code() {
  echo >&2 "Listing buckets"

  local single_keyval counter
  if [ -n "${filter}" ]; then
    single_keyval=$(echo "${filter}" | grep -E "^labels\.[a-z][a-z0-9_-]*=[a-z][a-z0-9_-]*$")
    if [ -n "$single_keyval" ]; then
      create_bucket_deletion_code_filtered_by_label
      return
    else
      echo >&2 "Warning: Will ignore filter for storage buckets, because \"${filter}\" is not a simple single-key label equality filter (key=value)."
      create_unfiltered_bucket_deletion_code
    fi
  else
    create_unfiltered_bucket_deletion_code
  fi

}
while getopts 'k:p:f:b' OPTION; do
  case "$OPTION" in
  k)
    key_file="$OPTARG"
    ;;
  p)
    project_id="$OPTARG"
    ;;
  f)
    filter="$OPTARG"
    # Trim leading and trailing whitespace
    filter=$(echo ${filter} | sed 's/ *$//g' | sed 's/^ *//')
    ;;
  b)
    async_ampersand="&"
    ;;
  ?)
    usage
    ;;
  esac
done

if [[ -z ${key_file} ]]; then
  key_file=project-viewer-credentials.json
  echo >&2 "Using default value for key file ${key_file}"
fi

if [[ -z ${project_id} ]]; then
  usage
fi

login
echo "set -x"
# There are dependencies:
# url-maps must be deleted before backend-services
# backend-services must be deleted before health-check
compute_resource_types="url-maps instances addresses backend-buckets backend-services disks \
firewall-rules forwarding-rules health-checks http-health-checks https-health-checks \
networks routes routers target-pools \
target-http-proxies target-https-proxies target-tcp-proxies"

create_deletion_code compute "${compute_resource_types}" "true"
# Use name, not URI, because of issue https://issuetracker.google.com/issues/160846601
create_deletion_code sql instances "false"
create_deletion_code container clusters "true"
create_deletion_code app "services firewall-rules" "true" # services covers versions and instances but we want to generate a list for human review
create_deletion_code pubsub "subscriptions topics snapshots" "true"
# Use name, not URI, because of issue https://issuetracker.google.com/issues/157285750
create_deletion_code functions "" "false"
create_bucket_deletion_code

# TODO More services, as follows
# TODO Implement ai-platform
# TODO Implement app versions and instances. Use Version/Instance name, not uri, and add option --service.
# TODO Implement bq with bq tool (maybe)
# TODO Implement composer
# TODO Implement datacatalog
# TODO Implement dataproc
# TODO Implement datastore (maybe)
# TODO Implement dataflow
# TODO Implement dns
# TODO Implement endpoints
# TODO Implement filestore
# TODO Implement firebase
# TODO Implement iam (be careful!)
# TODO Implement kms
# TODO Implement memcache (beta as of June 2020)
# TODO Implement ml
# TODO Implement ml-engine
# TODO Implement monitoring (dashboards etc)
# TODO Implement redis (need to specify --region)
# TODO Implement scheduler
# TODO Implement secrets
# TODO Implement tasks (need to specify --region)
# TODO More resource types inside each service.
#  For example, in compute: instance groups and
#  networks -- vpc, subnets, peerings, and vpc-access including vpc-access connectors.
#      This is useful as you cannot delete a VPC until you delete its subnets.
#      Note that this is the first subresource-type (i.e. four words in the structure gcloud x y z)
#      and so create_deletion_code will need to reflect that.
#      Also, though you do not need to specify --region in list command, you do need to add it to the
#      delete command.
