#!/bin/sh

#UPSTREAM_CONFIG=${1}
#echo $UPSTREAM_CONFIG | jq

UPSTREAM_NAME="${1}"
UPSTREAM_SERVERS="${2}"

#IFS=";" read -r -a SERVERS <<< "$UPSTREAM_SERVERS"
#SERVERS=$(echo $UPSTREAM_SERVERS | tr ";" "\n")
#echo $SERVERS

echo "upstream backend {"
echo $UPSTREAM_SERVERS | tr ";" "\n" | while read -r item; do
  if [ "$item" == "" ]; then
    continue
  fi
  echo "  server $item;"
done
echo "}"