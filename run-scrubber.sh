#!/bin/bash
./scrubber.sh -a project-viewer@joshua-playground.iam.gserviceaccount.com -k project-viewer-credentials.json -p joshua-playground 2>>errors.txt | \
 grep -v "firewalls\/default" | \
 grep -v "networks\/defaults"
