#!/bin/bash
# Run bash or any other command after setting fixuid
# and using the Tini init system to keep track of any subprocesses.

eval $(/bin/fixuid -q)

if [ $# -eq 0 ]
then
    exec /bin/tini -- bash
else
    exec /bin/tini -- "$@"
fi
