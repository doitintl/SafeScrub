# Safe Scrub

SafeScrub  deletes the unwanted resources in your Google Cloud Platform project, leaving it clean of confusing clutter and saving you money.

## Use case
- It is intended for development and QA project, where you want to start fresh at the end of the day or the end of a test run
- It is not intended for production projects. Even with the built-in safety measures, it is too dangerous to nuke an important project

## Safety First 
To keep it safe, Safe Scrub has these features:
- In normal mode, it does not delete resources; rather, it just  generates a script that deletes resources.
- We recommend that before running the script, you review it and remove any resources that you want to keep
- It supports a no-deletion filter  in `no-delete.txt`. Resources that have these strings in their URI will be excluded from the deletion script.
- It requires a JSON key file with credentials from a service account -- rather than your logged-in user account. 
  - So, the service account should have the Project Viewer role.
    - This gives no  write capabilities  
    - But it does give _full_ read access, as you may want to delete resources of many types.
  - You could give a more limited role if you only want to delete resources of certain types. 
- Safe Scrub keeps going if it cannot access some resoruces, as for example if the given GCP API is not enabled, or if the role of the service account does not have permissions to read these.

## Dangerous mode
To run the deletion script immediately, just pipe output to `bash`, as  in script `dangerous-generate-and-run.sh`.

## Features
- Today, resources within the APIS for GCE, GKE, Cloud SQL, PubSub and App Engine are supported. (See `generate-script.sh`) If you want more, please submit a Pull Request or ticket.
-
## Usage
`./generate-script.sh -a my-service-account@myproject.iam.gserviceaccount.com -k project-viewer-credentials.json -p  my-project`

    
