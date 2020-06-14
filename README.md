# Safe Scrub

SafeScrub  deletes the unwanted resources in your Google Cloud Platform project, leaving it clean of confusing clutter and saving you money.

## Use case
- It is intended for development and QA projects, where you want to start fresh at the end of the day or before a new test run.
- It is unlikely to be useful for production projects, where you should determine the potential dependencies between components before deleting
anything, and so should delete components individually.

## Safety First 
To keep it safe, Safe Scrub has these features in normal mode (`generate-script.sh`).
1. It requires you to specify a project, to avoid deleting a default project by accident.
1. It requires a JSON key file with credentials from a service account, rather than your logged-in user account. This requires you to consciously choose a role to use.
    - The service account should have the Project Viewer role. This gives no  write capabilities. (The base script-generartion script does not need or use write capabilities.)
    - You could give a more limited role if you only want to delete resources of certain types. Safe Scrub keeps going if it cannot access some resources, as for example if the given GCP API is not enabled, or if the role of the service account does not have permissions to read these.
1. It does not delete resources; rather, it just  generates a script that deletes resources. Review this deletion script before running it.
1. It supports a `--filter` command line option so you can choose just the resources you want using the 
full power of filters in `gcloud`, for example choosing resources by label. 
(Run `gcloud topic filters` for documentation.)
1. It supports a no-deletion list  in `no-delete.txt`. Resources that have these strings in their URI will be excluded from the deletion script.

## Actually deleting resources
### Deletion step
   - After generating the deletion script, review it and remove any resources that you want to keep.
   - Use a different role to run it, one with the relevant write permissions, like Project Editor.
### Dangerous mode
- To generate and run the deletion script  in one step, just pipe output to `bash`, as  in `dangerous-generate-and-run.sh`. 
- In this case, your service account should have read and write permissions, as for example Project Editor.

## Features
- Resource types from many APIs including  GCE, GKE, Cloud SQL, PubSub, and more are supported.
- Run `./generate-script.sh` to see a full list of supported APIs. Not necessarily all resource types in each API is supported. 
- If you want more APIs or resource  types, please submit a Pull Request or issue at GitHub.

## Usage
- Example: `./generate-script.sh -a project-viewer-service-account@myproject.iam.gserviceaccount.com -k project-viewer-credentials.json -p  my-project -f "labels.env=test OR tags.my-tag=abc"`
- For full filter syntax, run `gcloud topic filters`.
- Run `./generate-script.sh` to see usage text.
