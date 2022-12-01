#!/bin/sh

set -e

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

log_printf() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        printf "$@"
    fi
}

load_templates() {
  local templates_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/templates}"
  local conf_dir="${NGINX_ENVSUBST_CONF_DIR:-conf.d}"
  local upstreams_dir="${NGINX_UPSTREAMS_DIR:-upstreams.d}"
  local output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"
  local filter="${NGINX_ENVSUBST_FILTER:-}"
  local suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.conf}"

  log "$ME: "
  log "$ME: ------- Nginx templates generator -------"

  if [ ! -d "$templates_dir" ]; then
    log "$ME: No templates dir $templates_dir. Exit"
    return 0
  fi

  #---------------------------------------------------
  local env_path="$templates_dir/.env"
  if [ -f "$env_path" ]; then
    log_printf "$ME: Loading $env_path file "
    export $(grep -v '^#' "$env_path" | xargs)
    test $? -eq 0 && log "${GREEN}[LOADED]${NC}" || log "${RED}[ERROR]${NC}"
  else
    log "$ME: ${YELLOW}WARN env file $env_path not found -> no extra ENVs.${NC}"
  fi

  #---------------------------------------------------
  local defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" < /dev/null ))
  log "$ME: List of defined ENVs that can be used in templates: ${PURPLE}${defined_envs}${NC}"

  #---------------------------------------------------
  local template_nginx_conf="$templates_dir/nginx.conf"
  local dst_nginx_conf="/etc/nginx/nginx.conf"
  if [ -f "$template_nginx_conf" ]; then
    if [ ! -w /etc/nginx ]; then
      log "${RED}ERROR: directory /etc/nginx is not writable${RED}"
      return 0
    fi
    if [ ! -w "$dst_nginx_conf" ]; then
      log "${RED}ERROR: file $dst_nginx_conf is not writable${NC}"
      return 0
    fi
    log_printf "$ME: Templating $template_nginx_conf --> $dst_nginx_conf "
    ##printf "#---------------------------\n# This is a Templated version of nginx.conf.\n# It was created from template $template_nginx_conf. You can change that file and run $ME to reload.\n#---------------------------\n\n" > $dst_nginx_conf
    envsubst "$defined_envs" < "$template_nginx_conf" > $dst_nginx_conf
    log "${GREEN}[OK]${NC}"
  else
    log "$ME: ${YELLOW}WARN nginx.conf template $template_nginx_conf not found -> using default.${NC}"
  fi

  #---------------------------------------------------
  local template file_in_output_dir template_to_delete subdir relative_path output_path
  if [ -d "$templates_dir/$conf_dir" ]; then
    if [ ! -d "$output_dir" ]; then
      subdir=$(dirname "$output_dir")
      if [ ! -w "$subdir" ]; then
        log "$ME: ERROR: directory $subdir is not writable. Can't create dir $output_dir."
        return 0
      fi
      mkdir -p $output_dir
      log "$ME: Created $output_dir folder"
    fi

    if [ ! -w "$output_dir" ]; then
      log "$ME: ERROR: output dir $output_dir is not writable"
      return 0
    fi

    log "$ME: Templating files from $templates_dir/$conf_dir:"
    find "$templates_dir/$conf_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
      relative_path="${template#$templates_dir/$conf_dir/}"
      output_path="$output_dir/${relative_path}"
      subdir=$(dirname "$relative_path")

      # create a subdirectory where the template file exists
      mkdir -p "$output_dir/$subdir"

      log_printf "$ME:  - $template --> $output_path "
      envsubst "$defined_envs" < "$template" > "$output_path"
      test $? -eq 0 && log "${GREEN}[OK]${NC}" || log "${RED}[ERROR]${NC}"
    done

    log "$ME: Deleting files that are not present in the $templates_dir/$conf_dir folder but exist in the $output_dir folder:"
    find "$output_dir" -type f -print | while read -r file_in_output_dir; do
      relative_path="${file_in_output_dir#$output_dir/}"
      if [ ! -f "$templates_dir/$conf_dir/$relative_path" ]; then
        template_to_delete="$output_dir/$relative_path"
        log_printf "$ME:  - $template_to_delete "
        rm "$template_to_delete"
        test $? -eq 0 && log "${GREEN}[DELETED]${NC}" || log "${RED}[ERROR]${NC}"
      fi
    done

    log "$ME: ${GREEN}Current files in the $output_dir folder:${NC}"
    find "$output_dir" -type f -print | while read -r file_in_output_dir; do
      log "$ME:  - $file_in_output_dir"
    done

    CNT_INCLUDE=$(cat $dst_nginx_conf | grep "include $output_dir/" | wc -l)
    if [ "$CNT_INCLUDE" == "0" ]; then
      log "$ME: ${RED}WARN $dst_nginx_conf file does not have 'include $output_dir' directive -> templates won't be loaded. Maybe you forgot to set it?${NC}"
    fi
  else
    log "$ME: ${YELLOW}WARN templates directory $templates_dir/$conf_dir not found -> no changes.${NC}"
  fi

  #-------------------------------------
  if [ -d "$templates_dir/$upstreams_dir" ]; then
    local output_upstreams_dir="/etc/nginx/$upstreams_dir"
    if [ ! -d "$output_upstreams_dir" ]; then
      subdir=$(dirname "$output_upstreams_dir")
      if [ ! -w "$subdir" ]; then
        log "$ME: ERROR: directory $subdir is not writable. Can't create dir $output_upstreams_dir."
        return 0
      fi
      mkdir -p $output_upstreams_dir
      log "$ME: Created $output_upstreams_dir folder"
    fi

    if [ ! -w "$output_upstreams_dir" ]; then
      log "$ME: ERROR: output dir $output_upstreams_dir is not writable"
      return 0
    fi

    log "$ME: Templating files from $templates_dir/$upstreams_dir:"
    find "$templates_dir/$upstreams_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
      relative_path="${template#$templates_dir/$upstreams_dir/}"
      output_path="$output_upstreams_dir/${relative_path}"
      subdir=$(dirname "$relative_path")

      # create a subdirectory where the template file exists
      mkdir -p "$output_upstreams_dir/$subdir"

      log_printf "$ME:  - $template --> $output_path "
      envsubst "$defined_envs" < "$template" > "$output_path"
      test $? -eq 0 && log "${GREEN}[OK]${NC}" || log "${RED}[ERROR]${NC}"
    done

    log "$ME: Deleting files that are not present in the $templates_dir/$upstreams_dir folder but exist in the $output_upstreams_dir folder:"
    find "$output_upstreams_dir" -type f -print | while read -r file_in_output_dir; do
      relative_path="${file_in_output_dir#$output_upstreams_dir/}"
      if [ ! -f "$templates_dir/$upstreams_dir/$relative_path" ]; then
        template_to_delete="$output_upstreams_dir/$relative_path"
        log_printf "$ME:  - $template_to_delete "
        rm "$template_to_delete"
        test $? -eq 0 && log "${GREEN}[DELETED]${NC}" || log "${RED}[ERROR]${NC}"
      fi
    done

    log "$ME: ${GREEN}Current files in the $output_upstreams_dir folder:${NC}"
    find "$output_upstreams_dir" -type f -print | while read -r file_in_output_dir; do
      log "$ME:  - $file_in_output_dir"
    done

    CNT_INCLUDE=$(cat $dst_nginx_conf | grep "include $output_upstreams_dir/" | wc -l)
    if [ "$CNT_INCLUDE" == "0" ]; then
      log "$ME: ${RED}WARN $dst_nginx_conf file does not have 'include $output_upstreams_dir' directive -> templates won't be loaded. Maybe you forgot to set it?${NC}"
    fi
  else
    log "$ME: ${YELLOW}WARN upstreams directory $templates_dir/$upstreams_dir not found -> no changes.${NC}"
  fi

  #-------------------------------------
  HAS_AUTO_WORKER_PROCESSES=$(cat $dst_nginx_conf | grep -E "worker_processes\s+auto" | wc -l)
  if [ "$HAS_AUTO_WORKER_PROCESSES" == "0" ]; then
    log "$ME: Tuning worker_processes directive"
    ngx-tune-worker-processes.sh
  fi

  #-------------------------------------
  log "$ME: Testing configuration:"
  set +e
  nginx -t
  if [ ! $? -eq 0 ]; then
    log "$ME: ${RED}ERROR nginx configuration has some errors${NC}"
    exit 1
  fi
  set -e

  log "$ME: DONE"
}

load_templates
exit 0
