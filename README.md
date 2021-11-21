# Safe Scrub

Safe Scrub helps you delete the unwanted resources in your Google Cloud Platform project, 
leaving it clean of confusing clutter and saving you money.

# Article
See [the blog post](https://blog.doit-intl.com/safe-scrub-clean-up-your-google-cloud-projects-f90f18aca311)
for an explanation.

# Newer project
As of October 2021, please see [Cloud Blaster](https://github.com/doitintl/CloudBlaster), coded in Kotlin and so more robust.

## Use case
- It is intended for development and QA projects, where you want to start fresh at the end of the day or before a new test run.
- It is unlikely to be useful for production projects, where you should determine the potential dependencies between components before deleting
anything.

## Safety First 
To keep it safe, Safe Scrub has these features as you run `generate-deletion-script.sh`.
1. Safe Scrub _does not delete_ resources; rather, it just generates a simple script that deletes resources.
   - The deletion script is simply a list of `delete` statements, so that you can easily understand what it is going to do to your cloud.
   - Review the deletion script before running it.
1. Safe Scrub requires you to explicitly state a project, to avoid accidentally listing resources that come from
 a default project.
1. Safe Script specifies the project in the deletion script, so that deletion is not run against  your current default project.
1. Safe Scrub requires a JSON key file with credentials for a service account; it does not use your logged-in user account. 
    - This is designed to require a conscious choice of a role to use.
    - The service account should have a role with no write capabilities, like Project Viewer. The base script-generation script does not need or use write capabilities.
    - You could give a more limited role if you only want to delete resources of certain types. Safe Scrub keeps going if it cannot access some resources, 
    as for example if the given GCP API is not enabled, or if the role of the service account does not have permissions to read these.
1. Safe Scrub supports the `-f` command line option for filtering so you can choose just the resources you want,
 filtering by label, name, creation date, and much more. 
   - The implementation uses the `--filter` option from `gcloud`. For full documentaiton on the syntax, run  `gcloud topic filters`.
   - However, for Cloud Storage buckets, only simple single-key label equality filters  (`key=value1`) are supported. Otherwise, the filter is ignored.
1. Safe Scrub supports an exclusion list in `exclusions.txt`. 
   - Resources that have these strings in their URI will not be included in the deletion script.
   - To use this, run Safe Scrub, note items that should not be deleted in future, and add the given URI or an identifying part of the URI to `exclusions.txt`
   - For Cloud Functions, the name rather than the URI is used because of a bug in `gcloud`.
1. Safe Scrub prepends `set -x` to the deletion script so that you can see what it is doing as it runs.
1. Safe Scrub generates an ordinary sequential script, for easier monitoring when it is executed. However, you can set it to generate
background (asynchronous) commands using the `-b` switch, so that deletion  of multiple resources will happen 
concurrently. This is faster, but harder to track, and risks overloading systems with too many parallel calls.
 
## Actually deleting resources
### Deletion step
  - After generating the deletion script, review it and remove lines for any resources that you want to keep.
  - Use a different role to run it, one with the relevant write permissions, like Project Editor.
### Dangerous mode
  - To generate and run the deletion script in one step, just pipe output to `bash`, as in `dangerous-usage-example.sh`. 
  - In this case, your service account should have read and write permissions, as for example Project Editor.

## Features
- I focused on the common important resource types that are set up and torn down
 in typical development and QA.
- This includes resource types from many services including GCE instances and firewall rules,
PubSub topics and subscriptions, and more. 
- For a full list of supported services, see the usage text. (Run  `./generate-deletion-script.sh -h`).  
- Some services that are not supported yet: DataProc, Composer, Tasks, Spanner, BigTable, BigQuery, Dataflow, ML,
Redis, Memcache, Filestore, Scheduler, KMS, Secrets, Firebase, Data Catalog, Container Registry, 
and IAM (though perhaps you would not want to delete IAM objects!)
- Not necessarily all resource types in each service are supported. Anything that 
requires a `--region` specification is not yet supported.
- If you want more services or resource types, please submit a pull request or issue at GitHub.

## Usage
- See `usage-example.sh`. This example shows command line options and how to generate an executable deletion script.
- For usage text, run `./generate-deletion-script.sh -h`.

# Other projects and approaches
- [GCP Cleaner](https://github.com/paulczar/gcp-cleaner/blob/master/delete-all.sh), 
[Travis CI GCloud Cleanup](https://github.com/travis-ci/gcloud-cleanup) and [Bazooka](https://github.com/enxebre/bazooka) also delete GCE resources.
- [Cloud Nuke](https://blog.gruntwork.io/cloud-nuke-how-we-reduced-our-aws-bill-by-85-f3aced4e5876) does this for AWS.
-  `gcloud alpha resources list --uri |grep "projects\/$PROJECT\/"` (in alpha as of June 2020) and may provide
  a re-implementation that truly captures all resources. Still, implementing each service explicitly, 
  as here, may be necessary as there are slightly different deletion commands.
