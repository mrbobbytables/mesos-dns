#!/bin/bash

mld=${MESOSDNS_LOG_DIR:-/var/log/mesos-dns}

cd "$mld"

#logrotate trigger --
lr_trigger=false

if [[ -h mesos-dns.INFO ]]; then
  info_size=$(ls -la --block-size=M $(readlink mesos-dns.INFO) | awk '{print substr($5, 0, length($5))}')
  if [[ $info_size -ge 10 ]]; then
    lr_trigger=true
  fi
fi

if [[ -h mesos-dns.ERROR ]]; then
  error_size=$(ls -la --block-size=M $(readlink mesos-dns.ERROR) | awk '{print substr($5, 0, length($5))}')
  if [[ $error_size -ge 10 ]]; then
    lr_trigger=true
  fi
fi

if [[ -h mesos-dns.WARNING ]]; then
  warning_size=$(ls -la --block-size=M $(readlink mesos-dns.WARNING) | awk '{print substr($5, 0, length($5))}')
  if [[ $warning_size -ge 10 ]]; then
    lr_trigger=true
  fi
fi

if [[ $lr_trigger == true  ]]; then
  supervisorctl restart mesos-dns
fi

(ls -t | grep 'log.INFO.*'|head -n 5;ls)|sort|uniq -u|grep 'log.INFO.*'|xargs --no-run-if-empty rm
(ls -t | grep 'log.ERROR.*'|head -n 5;ls)|sort|uniq -u|grep 'log.ERROR.*'|xargs --no-run-if-empty rm
(ls -t | grep 'log.WARNING.*'|head -n 5;ls)|sort|uniq -u|grep 'log.WARNING.*'|xargs --no-run-if-empty rm

#consul-template uses rsyslog for logging, need to run logrotate to handle that log
if [[ "$SERVICE_CONSUL_TEMPLATE" == "enabled" ]]; then
  /usr/sbin/logrotate /etc/logrotate.conf
fi

