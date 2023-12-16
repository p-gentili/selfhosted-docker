#!/bin/bash

sudo docker network create frontend 2> /dev/null
sudo find . -name "docker-compose.yml" -exec docker compose -f {} up -d \;
