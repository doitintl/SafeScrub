#!/bin/bash

./base-generate-script.sh  "$@"  | \
grep -v -f no-delete.txt
