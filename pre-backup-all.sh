#!/bin/bash

DIRNAME=$(dirname "$(realpath "$0")")

sudo find $DIRNAME -name "pre-backup.sh" -exec {} \;
