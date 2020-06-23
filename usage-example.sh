#!/usr/bin/env bash

# In this example, we send the output of the generation script into a new deletion script,
# and set access permissions for this script to be executable.

# The parameter -k here is redundant, as the default value is given.
# The parameter -b could be added to generate a parallelized script.

./generate-deletion-script.sh \
  -k project-viewer-credentials.json \
  -p my-project \
  -f "labels.key1=val1" \
  > deletion-script.sh && chmod a+x deletion-script.sh


