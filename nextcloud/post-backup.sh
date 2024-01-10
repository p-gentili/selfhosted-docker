#!/bin/bash
docker exec -u www-data nextcloud php occ maintenance:mode --off
