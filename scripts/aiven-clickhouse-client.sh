#!/bin/bash

usage() {
  printf "\nClickHouse CLI wrapper script\n"
  printf "\n# clickhouse-client CLI\naiven-clickhouse.sh [-s|--service-name] clickhouse-service\n"
  exit 0
}

ARGS=()
DOCKER_CMD="docker run -it"

while [[ $# -gt 0 ]]
do
  case $1 in
    -s|--service-name)
      SERVICE="$2"
      shift
      shift
      ;;
    -h|--help)
      usage
      ;;
  esac
done

eval $(avn service user-list --format \
  'DATABASE_PASSWORD={password} DATABASE_USER={username}' \
   $SERVICE)

SERVICE_URI=$(avn service get $SERVICE --format '{service_uri}')
DATABASE_HOST=$(echo $SERVICE_URI|cut -d: -f1)
DATABASE_PORT=$(echo $SERVICE_URI|cut -d: -f2)

eval $(echo $DOCKER_CMD \
  --rm clickhouse/clickhouse-client \
  --user $DATABASE_USER \
  --password $DATABASE_PASSWORD \
  --host $DATABASE_HOST \
  --port $DATABASE_PORT \
  --secure \
  $1)
