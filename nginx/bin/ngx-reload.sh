#!/bin/sh

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GRAY='\033[0;37m'
NC='\033[0m' # No Color

ME=$(basename $0)

log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo -e "$@"
    fi
}

log "$ME: "
log "$ME: ------- Nginx Reloader -------"

nginx -t
if [ ! $? -eq 0 ]; then
  echo -e "$ME: ${RED}ERROR: wrong configuration${NC}"
  exit 1
fi

nginx -s reload
if [ ! $? -eq 0 ]; then
  echo -e "$ME: ${RED}ERROR while reloading${NC}"
  exit 1
fi

echo -e "$ME: ${GREEN}Nginx RELOADED!${NC}"