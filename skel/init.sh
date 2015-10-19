#!/bin/bash

########## Mesos DNS ##########
# Init Script for Mesos DNS
########## Mesos DNS ##########

source /opt/scripts/container_functions.lib.sh

init_vars() {

  if [[ $ENVIRONMENT_INIT && -f $ENVIRONMENT_INIT ]]; then
      source "$ENVIRONMENT_INIT"
  fi 

  if [[ ! $PARENT_HOST && $HOST ]]; then
    export PARENT_HOST="$HOST"
  fi

  export APP_NAME=${APP_NAME:-mesos-dns}
  export ENVIRONMENT=${ENVIRONMENT:-local}
  export PARENT_HOST=${PARENT_HOST:-unknown}

  local mesos_dns_cmd=""
  export MESOSDNS_AUTOCONF=${MESOSDNS_AUTOCONF:-enabled}
  export MESOSDNS_CONF=${MESOSDNS_CONF:-/etc/mesos-dns/config.json}

  export SERVICE_LOGSTASH_FORWARDER_CONF=${SERVICE_LOGSTASH_FORWARDER_CONF:-/opt/logstash-forwarder/mesos-dns.conf}
  export SERVICE_REDPILL_MONITOR=${SERVICE_REDPILL_MONITOR:-mesos-dns}


  case "${ENVIRONMENT,,}" in
    prod|production|dev|development)
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-enabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-enabled}
      export MESOSDNS_OPTS=${MESOSDNS_OPTS:-"-log_dir=/var/log/mesos-dns"}
      ;;
    debug)
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-disabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-disabled}
      export MESOSDNS_OPTS=${MESOSDNS_OPTS:-"-v=2 -logtostderr=true"}
      ;;
    local|*)
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-disabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-enabled}
      export MESOSDNS_OPTS=${MESOSDNS_OPTS:-"-logtostderr=true"}
      ;;
  esac
 
  mesos_dns_cmd="$(__escape_svsr_txt "/usr/local/bin/mesos-dns -config=\"$MESOSDNS_CONF\" $MESOSDNS_OPTS")"
  export SERVICE_MESOSDNS_CMD=${SERVICE_MESOSDNS_CMD:-"$mesos_dns_cmd"}
}


config_mesos_dns() {

  local masters_arr=()
  local masters=""
  local resolvers_arr=()
  local resolvers=""
  local ipsource_arr=()
  local ipsources=""



  echo "{" > "$MESOSDNS_CONF"
  for i in $(compgen -A variable | awk '/^MESOSDNS_/ && !/MESOSDNS_AUTOCONF/ && !/MESOSDNS_CONF/ && !/MESOSDNS_OPTS/'); do
    local var_name="$(echo "${i:9}" | awk '{print tolower($0)}')"
    local var_value="${!i}"
    case $var_name in
      masters_*)
        masters_arr+=( "$var_value" )
        ;;
      resolvers_*)
        resolvers_arr+=( "$var_value" )
        ;;
      ipsource_*)
        ipsource_arr+=( "$var_value" )
        ;;
      # string values  
      domain|listener|soamname|soarname|zk)
        echo "\"$var_name\": \"$var_value\"," >> "$MESOSDNS_CONF"
        ;;
      # bool or int values
      dnson|enforcerfc952|externalon|httpon|httpport|port|recurseon|refreshseconds|soaexpire|soaminttl|soarefresh|soaretry|timeout|ttl|zkdetectiontimeout)
        echo "\"$var_name\": $var_value," >> "$MESOSDNS_CONF"
        ;;
      esac
  done

  masters="\"masters\": ["
  for master in "${masters_arr[@]}"; do
    masters+=" \"$master\","
  done
  masters="${masters::-1} ],"

  resolvers="\"resolvers\": ["
  for resolver in "${resolvers_arr[@]}"; do
    resolvers+=" \"$resolver\","
  done
  resolvers="${resolvers::-1} ],"

  if [[ ${#ipsource_arr[@]} -ne 0 ]]; then
    ipsources="\"ipsources\": ["
    for ipsource in "${ipsource_arr[@]}"; do
      ipsources+=" \"$ipsource\","
    done
    ipsources="${ipsources::-1} ]"
  fi

  echo "$masters" >> "$MESOSDNS_CONF"

  if [[ ! $ipsources ]]; then
    resolvers="${resolvers::-1}"
    echo "$resolvers" >> "$MESOSDNS_CONF"
  else
    echo "$resolvers" >> "$MESOSDNS_CONF"
    echo "$ipsources" >> "$MESOSDNS_CONF"
  fi

  echo "}" >> "$MESOSDNS_CONF"
}

main() {

  init_vars

  echo "[$(date)][App-Name] $APP_NAME"
  echo "[$(date)][Environment] $ENVIRONMENT"

  __config_service_logstash_forwarder
  __config_service_redpill

  if [[ "${MESOSDNS_AUTOCONF,,}" == "enabled" ]]; then
    config_mesos_dns
  fi

  echo "[$(date)][Mesos-DNS][Auto-Config] $MESOSDNS_AUTOCONF"
  echo "[$(date)][Mesos-DNS][Configuration-File] $MESOSDNS_CONF"
  echo "[$(date)][Mesos-DNS][Start-Command] $SERVICE_MESOSDNS_CMD"

  exec supervisord -n -c /etc/supervisor/supervisord.conf

}

main "$@"
