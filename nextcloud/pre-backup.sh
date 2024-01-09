#!/bin/bash

source .env

docker exec -u www-data php occ maintenance:mode --on
docker exec db_container_name mysqldump [--user nextcloud] [--password=$MYSQL_PASSWORD] databasename > dump.bak
