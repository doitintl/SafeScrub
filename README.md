# Safe Scrub

Safe Scrub helps you delete the unwanted resources in your Google Cloud Platform project, 
leaving it clean of confusing clutter and saving you money.

## Use case
- It is intended for development and QA projects, where you want to start fresh at the end of the day or before a new test run.
- It is unlikely to be useful for production projects, where you should determine the potential dependencies between components before deleting
anything.

## Safety First 
To keep it safe, Safe Scrub has these features as you run `generate-script.sh`.
1. Safe Scrub _does not delete_ resources; rather, it just generates a simple script that deletes resources.
   - The deletion script is simply a list of `delete` statements, so that you can easily understand what it is going to do to your cloud.
   - Review the deletion script before running it.
1. Safe Scrub requires you to specify a project, to avoid deleting a default project by accident.
1. Safe Scrub requires a JSON key file with credentials for a service account, rather than your logged-in user account. 
    - This is designed to require the conscious choice of a role to use.
    - The service account should have a role with no write capabilities, like Project Viewer. (The base script-generation script does not need or use write capabilities.)
    - You could give a more limited role if you only want to delete resources of certain types. Safe Scrub keeps going if it cannot access some resources, as for example if the given GCP API is not enabled, or if the role of the service account does not have permissions to read these.
1. Safe Scrub supports a `--filter` command line option so you can choose just the resources you want,
 filtering by label, name, creation date, and much more. 
   - Run `gcloud topic filters` for full documentation.
   - For Cloud Storage buckets, only simple single-key label equality filters  (`key=value1`) are supported. Otherwise, the filter is ignored.
1. Safe Scrub supports a no-deletion list in `no-delete.txt`. Resources that have these strings in their URI will be excluded from the deletion script.

## Actually deleting resources
### Deletion step
  - After generating the deletion script, review it and remove lines for any resources that you want to keep.
  - Use a different role to run it, one with the relevant write permissions, like Project Editor.
### Dangerous mode
  - To generate and run the deletion script in one step, just pipe output to `bash`, as in `dangerous-usage-example.sh`. 
  - In this case, your service account should have read and write permissions, as for example Project Editor.

## Features
- I focused on the common important resource types that needs to be set up and torn down
 in typical development and QA.
- This includes resource types from many APIs including GCE instances and firewall rules,
PubSub topics and subscriptions, and more. 
- For a full list of supported APIs, see the usage text. (Run  `./generate-script.sh -h`).  
- Not necessarily all resource types in each API are supported. 
- If you want more APIs or resource types, please submit a pull request or issue at GitHub.

## Usage
- See `usage-example.sh`. This example shows command line options and how to generate an executable deletion script.
- For usage text, run `./generate-script.sh -h`.