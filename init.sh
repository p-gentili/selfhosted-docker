#!/bin/bash

sudo docker network create frontend 2> /dev/null
sudo find . -name "init.sh" -exec {} \;
