#!/bin/bash

./gen-scrub-script.sh  "$@"  | \
grep -v -f no-delete.txt
