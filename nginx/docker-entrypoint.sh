#!/bin/sh
# vim:sw=4:ts=4:et

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo -e "$@"
    fi
}

entrypoint_log "$0: "
entrypoint_log "$0: ${CYAN}------- 🔥 Nginx Entrypoint 🔥 -------${NC}"

if [ "$1" = "nginx" -o "$1" = "nginx-debug" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        entrypoint_log "$0: Running shell scripts in /docker-entrypoint.d/ folder"

        find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
            case "$f" in
                *.envsh)
                    if [ -x "$f" ]; then
                        entrypoint_log "$0: Sourcing $f";
                        . "$f"
                    else
                        # warn on shell scripts without exec bit
                        entrypoint_log "$0: ${YELLOW}Ignoring $f, not executable.${NC}";
                    fi
                    ;;
                *.sh)
                    if [ -x "$f" ]; then
                        entrypoint_log "$0: Launching $f";
                        "$f"
                    else
                        # warn on shell scripts without exec bit
                        entrypoint_log "$0: ${YELLOW}Ignoring $f, not executable.${NC}";
                    fi
                    ;;
                *)
                    entrypoint_log "$0: ${YELLOW}Ignoring $f. Only supported *.sh and *.envsh files.${NC}";;
            esac
        done

        entrypoint_log "$0: ${GREEN}Configuration complete; ready for start up!${NC}"
    else
        entrypoint_log "$0: ${YELLOW}The folder /docker-entrypoint.d/ has no files, skipping configuration.${NC}"
    fi
fi

entrypoint_log "$0: DONE"

exec "$@"
