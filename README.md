# - Mesos DNS -

An Ubuntu based container - built for running the Mesos-DNS support service. It comes bundled with Logstash-Forwarder, and is managed by Supervisord. All parameters are controlled through environment variables, with some settings auto-configured based on the environment.


##### Version Information:
* **Container Release:** 1.3.0
* **Mesos-DNS:** 0.5.1

##### Services Include:
* **[Mesos-DNS](#mesos-dns)** - A small application that provides DNS as a method of service discovery for applications launched via Mesos and it's associated frameworks.
* **[Consul-Template](#consul-template)** - An application that can populate configs from a consul service.
* **[Logrotate](#logrotate)** - A script and application that aid in pruning log files.
* **[Logstash-Forwarder](#logstash-forwarder)** - A lightweight log collector and shipper for use with [Logstash](https://www.elastic.co/products/logstash).
* **[Redpill](#redpill)** - A bash script and healthcheck for supervisord managed services. It is capable of running cleanup scripts that should be executed upon container termination.
* **[Rsyslog](#rsyslog)** - The system logging daemon.

---
---

### Index

* [Usage](#usage)
 * [Example Run Command](#example-run-command)
 * [Example Marathon App Definition](#example-marathon-app-definition)
* [Modification and Anatomy of the Project](#modification-and-anatomy-of-the-project)
* [Important Environment Variables](#important-environment-variables)
* [Service Configuration](#service-configuration)
 * [Mesos-DNS](#mesos-dns)
 * [Consul-Template](#consul-template)
 * [Logrotate](#logrotate)
 * [Logstash-Forwarder](#logstash-forwarder)
 * [Redpill](#redpill)
 * [Rsyslog](#rsyslog)
* [Troubleshooting](#troubleshooting)

---

### Usage
The Mesos-DNS container is fairly easy to get going. Outside of running the container with host networking and specifying the `ENVIRONMENT`, the only required variables that must be defined are `MESOSDNS_ZK` or `MESOSDNS_MASTERS_###`, and `MESOSDNS_RESOLVERS_###`.

* `MESOSDNS_ZK` - The Zookeeper Mesos uri. e.g. `zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos`

* `MESOSDNS_MASTERS_###` - The address of the Mesos masters in the form of **ip:port**. e.g. `MESOSDNS_MASTERS_1=10.10.0.11:5050`. If `MESOSDNS_ZK` is already set, these are not necessary.
 
* `MESOSDNS_RESOLVERS_###` - The IP of an upstream DNS server. More than one can be specified using the same syntax as `MESOSDNS_MASTERS_###` e.g. `MESOSDNS_RESOLVERS_1=8.8.8.8`


With `MESOSDNS_AUTOCONF` enabled. The init script will assemble a Mesos-DNS config file based on environment variables beginning with the prefix `MESOSDNS_`. The environment variable names correspond with their associated Mesos-DNS config option. e.g. the option `"domain": "mesos"` would map to `MESOSDNS_DOMAIN="mesos"`.


For options that would be represented by an array, they can be passed by adding an `_` followed by a number from 0-999. e.g. `"masters": ["10.10.0.11:5050", "10.10.0.12:5050", "10.10.0.13:5050"]` would map to:
```
MESOSDNS_MASTERS_1="10.10.0.11:5050"
MESOSDNS_MASTERS_2="10.10.0.12:5050"
MESOSDNS_MASTERS_3="10.10.0.13:5050"
```


Alternatively, if you already have a Mesos-DNS config, `MESOSNS_AUTOCONF` can be disabled and all that is required is supplying the path in the `MESOSDNS_CONF` variable.

For a full list of Mesos-DNS options, please see the [Mesos-DNS Service](#mesos-dns) section, or visit [Mesos-DNS](http://mesosphere.github.io/mesos-dns/docs/configuration-parameters.html) main documentation page.

**Marathon Deployments**
For Marathon based deployments; if healthchecks are going to be used - the Mesos-DNS webserver should be enabled and the Marathon healthcheck itself must be a `COMMAND` based healthcheck. This is the case for anything with host based networking.


---

### Example Run Command

```bash
docker run -d --net=host \
-e ENVIRONMENT=production \
-e PARENT_HOST=$(hostname) \
-e MESOSDNS_ZK="zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos" \
-e MESOSDNS_MASTERS_1="10.10.0.11:5050" \
-e MESOSDNS_MASTERS_2="10.10.0.12:5050" \
-e MESOSDNS_MASTERS_3="10.10.0.13:5050" \
-e MESOSDNS_RESOLVERS_1="8.8.8.8" \
-e MESOSDNS_RESOLVERS_2="8.8.4.4" \
-e MESOSDNS_DOMAIN="mesos" \
-e MESOSDNS_REFRESHSECONDS=60 \
-e MESOSDNS_TTL=60 \
-e MESOSDNS_TIMEOUT=5 \
-e MESOSDNS_PORT=53 \
-e MESOSDNS_HTTPPORT=8123 \
mesos-dns
```

---

### Example Marathon App Definition

```json
{
    "id": "/mesos-dns",
    "instances": 1,
    "cpus": 0.5,
    "mem": 512,
    "constraints": [
        [
            "hostname",
            "CLUSTER",
            "10.10.111"
        ]
    ],
    "container": {
        "type": "DOCKER",
        "docker": {
            "image": "registry.address/mesos-dns",
            "network": "HOST"
        }
    },
    "env": {
        "ENVIRONMENT": "production",
        "MESOSDNS_ZK": "zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos",
        "MESOSDNS_MASTERS_1": "10.10.0.11:5050",
        "MESOSDNS_MASTERS_2": "10.10.0.12:5050",
        "MESOSDNS_MASTERS_3": "10.10.0.13:5050",
        "MESOSDNS_RESOLVERS_1": "8.8.8.8",
        "MESOSDNS_RESOLVERS_2": "8.8.4.4",
        "MESOSDNS_DOMAIN": "mesos",
        "MESOSDNS_REFRESHSECONDS": "60",
        "MESOSDNS_TTL": "60",
        "MESOSDNS_TIMEOUT": "5",
        "MESOSDNS_PORT": "53",
        "MESOSDNS_HTTPORT": "8123"
    },
    "healthChecks": [
        {
            "protocol": "COMMAND",
            "command": {
                "value": "curl -f -X GET http://$HOST:8123/v1/version"
            },
            "gracePeriodSeconds": 30,
            "timeoutSeconds": 60,
            "maxConsecutiveFailures": 5
        }
    ],
    "backoffSeconds": 1,
    "backoffFactor": 1.5,
    "maxLaunchDelaySeconds": 3600,
    "uris": [
        "file: ///docker.tar.gz"
    ]
}
```


---
---

### Modification and Anatomy of the Project

**File Structure**
The directory `skel` in the project root maps to the root of the filesystem once the container is built. Files and folders placed there will map to their corresponding location within the container.

**Init**
The init script (`./init.sh`) found at the root of the directory is the entry process for the container. It's role is to simply set specific environment variables and modify any subsequently required configuration files.

**Supervisord**
All supervisord configs can be found in `/etc/supervisor/conf.d/`. Services by default will redirect their stdout to `/dev/fd/1` and stderr to `/dev/fd/2` allowing for service's console output to be displayed. Most applications can log to both stdout and their respectively specified log file. 

In some cases (such as with zookeeper), it is possible to specify different logging levels and formats for each location.

**Logstash-Forwarder**
The Logstash-Forwarder binary and default configuration file can be found in `/skel/opt/logstash-forwarder`. It is ideal to bake the Logstash Server certificate into the base container at this location. If the certificate is called `logstash-forwarder.crt`, the default supplied Logstash-Forwarder config should not need to be modified, and the server setting may be passed through the `SERICE_LOGSTASH_FORWARDER_ADDRESS` environment variable.

In practice, the supplied Logstash-Forwarder config should be used as an example to produce one tailored to each deployment.

---
---

### Important Environment Variables

Below is the minimum list of variables to be aware of when deploying the Mesos-DNS container.

#### Defaults

| Variable                          | Default                                  |
|-----------------------------------|------------------------------------------|
| `ENVIRONMENT_INIT`                |                                          |
| `APP_NAME`                        | `mesos-dns`                              |
| `ENVIRONMENT`                     | `local`                                  |
| `PARENT_HOST`                     | `unknown`                                |
| `MESOSDNS_AUTOCONF`               | `enabled`                                |
| `MESOSDNS_CONF`                   | `/etc/mesos-dns/config.json`             |
| `MESOSDNS_MASTERS_###`            |                                          |
| `MESOSDNS_ZK`                     |                                          |
| `MESOSDNS_RESOLVERS_###`          |                                          |
| `MESOSDNS_LISTENER`               | `0.0.0.0`                                |
| `SERVICE_CONSUL_TEMPLATE`         | `disabled`                               |
| `SERVICE_LOGROTATE`               |                                          |
| `SERVICE_LOGROTATE_INTERVAL`      | `3600` (set in script by default)        |
| `SERVICE_LOGROTATE_SCRIPT`        | `/opt/scripts/purge-mdns-logs.sh`        |
| `SERVICE_LOGSTASH_FORWARDER`      |                                          |
| `SERVICE_LOGSTASH_FORWARDER_CONF` | `/opt/logstash-forwarder/mesos-dns.conf` |
| `SERVICE_REDPILL`                 |                                          |
| `SERVICE_REDPILL_MONITOR`         | `mesos-dns`                              |
| `SERVICE_RSYSLOG`                 | `disabled` *                             |

\* `SERVICE_RSYSLOG` is automatically enabled if `SERVICE_CONSUL_TEMPLATE` is enabled to ensure logging.

##### Description

* `ENVIRONMENT_INIT` - If set, and the file path is valid. This will be sourced and executed before **ANYTHING** else. Useful if supplying an environment file or need to query a service such as consul to populate other variables.

* `APP_NAME` - A brief description of the container. If Logstash-Forwarder is enabled, this will populate the `app_name` field in the Logstash-Forwarder configuration file.

* `ENVIRONMENT` - Sets defaults for several other variables based on the current running environment. Please see the [environment](#environment) section for further information. If logstash-forwarder is enabled, this value will populate the `environment` field in the logstash-forwarder configuration file.

* `PARENT_HOST` - The name of the parent host. If Logstash-Forwarder is enabled, this will populate the `parent_host` field in the Logstash-Forwarder configuration file.

* `MESOSDNS_AUTOCONF` - If this is enabled, the init script will attempt to autogenerate a config based on additional environment variables being passed. Please see the [Usage](#usage) section for more information.

* `MESOSDNS_CONF` - The path to the Mesos-DNS configuration file (json format)

* `MESOSDNS_MASTERS_###` - All `MESOSDNS_MASTERS_###` are converted to comma separated list with the IP address and port number for the master(s) in the Mesos cluster. Mesos-DNS will automatically find the leading master at any point in order to retrieve state about running tasks. If there is no leading master or the leading master is not responsive, Mesos-DNS will continue serving DNS requests based on stale information about running tasks. The `masters` field is **required**.

* `MESOSDNS_ZK` -`MESOSDNS_ZK` is a link to the Zookeeper instances on the Mesos cluster. Its format is `zk://host1:port1,host2:port2/mesos/`, where the number of hosts can be one or more. The default port for Zookeeper is 2181. Mesos-DNS will monitor the Zookeeper instances to detect the current leading master.

* `MESOSDNS_RESOLVERS_###` - ALL `MESOSDNS_RESOLVERS_###` are converted to a comma separated list with the IP addresses of external DNS servers that Mesos-DNS will contact to resolve any DNS requests outside the domain. We recommend that you list the nameservers specified in the `/etc/resolv.conf` on the server Mesos-DNS is running. Alternatively, you can list 8.8.8.8, which is the Google public DNS address. The resolvers field is **required**.

* `MESOSDNS_LISTENER` - It is the IP address of Mesos-DNS. In SOA replies, Mesos-DNS identifies hostname mesos-dns.domain as the primary nameserver for the domain. It uses this IP address in an A record for mesos-dns.domain. The default value is "0.0.0.0", which instructs Mesos-DNS to create an A record for every IP address associated with a network interface on the server that runs the Mesos-DNS process.

* `SERVICE_CONSUL_TEMPLATE` - Enables or disables the consul-template service. (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGROTATE` - Enables or disabled the Logrotate service. This will be set automatically depending on the environment. (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGROTATE_INTERVAL` - The time in seconds between runs of logrotate or the logrotate script. The default (3600 or 1 hour) is set by default in the logrotate script automatically.

* `SERVICE_LOGROTATE_SCRIPT` - The path to the script that should be executed instead of logrotate itself to clean up logs.

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor.

* `SERVICE_RSYSLOG` - Enables of disables the rsyslog service. This is managed by `SERVICE_CONSUL_TEMPLATE`, but can be enabled/disabled manually.

---

##### Environment

* `local` (default)

| **Variable**                 | **Default**                                         |
|------------------------------|-----------------------------------------------------|
| `SERVICE_LOGROTATE`          | `enabled`                                           |
| `SERVICE_LOGSTASH_FORWARDER` | `disabled`                                          |
| `SERVICE_REDPILL`            | `enabled`                                           |
| `MESOSDNS_OPTS`              | `-log_dir=/var/log/mesos-dns -alsologtostderr=true` |


* `prod`|`production`|`dev`|`development`

| **Variable**                 | **Default**                     |
|------------------------------|---------------------------------|
| `SERVICE_LOGROTATE`          | `enabled`                       |
| `SERVICE_LOGSTASH_FORWARDER` | `enabled`                       |
| `SERVICE_REDPILL`            | `enabled`                       |
| `MESOSDNS_OPTS`              | `-log_dir=/var/log/mesos-dns`   |


* `debug`

| **Variable**                 | **Default**                |
|------------------------------|----------------------------|
| `SERVICE_LOGROTATE`          | `disabled`                 |
| `SERVICE_LOGSTASH_FORWARDER` | `disabled`                 |
| `SERVICE_REDPILL`            | `disabled`                 |
| `MESOSDNS_OPTS`              | `-v=2 -logtostderr=true`   |
| `CONSUL_TEMPLATE_LOG_LEVEL`  | `debug`*                   |

\* Only set if `SERVICE_CONSUL_TEMPLATE` is set to `enabled`.


---
---

### Service Configurations

#### Mesos-DNS

| **Variable**                   | **Default**                                                   |
|--------------------------------|---------------------------------------------------------------|
| `MESOSDNS_AUTOCONF`            | `enabled`                                                     |
| `MESOSDNS_CONF`                | `/etc/mesos-dns/config.json`                                  |
| `MESOSDNS_OPTS`                |                                                               |
| `MESOSDNS_ZK`                  |                                                               |
| `MESOSDNS_ZKDETECTIONTIMEOUT`  | `30`                                                          |
| `MESOSDNS_MASTERS_###`         |                                                               |
| `MESOSDNS_REFRESHSECONDS`      | `60`                                                          |
| `MESOSDNS_TTL`                 | `60`                                                          |
| `MESOSDNS_DOMAIN`              | `mesos`                                                       |
| `MESOSDNS_PORT`                | `53`                                                          |
| `MESOSDNS_RESOLVERS_###`       |                                                               |
| `MESOSDNS_TIMEOUT`             | `5`                                                           |
| `MESOSDNS_HTTPON`              | `true`                                                        |
| `MESOSDNS_DNSON`               | `true`                                                        |
| `MESOSDNS_HTTPPORT`            | `8123`                                                        |
| `MESOSDNS_EXTERNALON`          | `true`                                                        |
| `MESOSDNS_LISTENER`            | `0.0.0.0`                                                     |
| `MESOSDNS_SOAMNAME`            | `ns1.mesos`                                                   |
| `MESOSDNS_SOARNAME`            | `root.ns1.mesos`                                              |
| `MESOSDNS_SOAREFRESH`          | `60`                                                          |
| `MESOSDNS_STATETIMEOUTSECONDS` | `300`                                                         |
| `MESOSDNS_RETRY`               | `600`                                                         |
| `MESOSDNS_EXPIRE`              | `86400`                                                       |
| `MESOSDNS_SOAMINTTL`           | `60`                                                          |
| `MESOSDNS_RECURSEON`           | `true`                                                        |
| `MESOSDNS_ENFORCERFC952`       | `false`                                                       |
| `MESOSDNS_IPSOURCES_###`       | `netinfo`, `mesos`, `host`, `docker`                          |
| `SERVICE_MESOSDNS_CMD`         | `/usr/bin/mesos-dns -config="$MESOSDNS_CONF" $MESOSDNS_OPTS"` |


##### Description

* `MESOSDNS_AUTOCONF` - If this is enabled, the init script will attempt to autogenerate a config based on additional environment variables being passed. Please see the [Usage](#usage) section for more information.

* `MESOSDNS_CONF` - The path to the Mesos-DNS configuration file (json format)

* `MESOSDNS_OPTS` - Additional Options to pass to Mesos-DNS. This generally control logging options. For more information see the Mesos-DNS Help text below.

* `SERVICE_MESOSDNS_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


##### Mesos-DNS configuration options:
**Notes:**

1. These descriptions are taken right from the [Mesos-DNS documentation page](http://mesosphere.github.io/mesos-dns/docs/configuration-parameters.html) with a few modifications to fit how they're used in this project. They are listed here for convenience.
2. It is sufficient to specify just one of the `MESOSDNS_ZK` or `MESOSDNS_MASTERS_###`. If both are defined, Mesos-DNS will first attempt to detect the leading master through Zookeeper. If Zookeeper is not responding, it will fall back to using the masters field. Both zk and master fields are static. To update them you need to restart Mesos-DNS. We recommend you use the zk field since this allows the dynamic addition to Mesos masters.

##### Description

* `MESOSDNS_ZK` -`MESOSDNS_ZK` is a link to the Zookeeper instances on the Mesos cluster. Its format is `zk://host1:port1,host2:port2/mesos/`, where the number of hosts can be one or more. The default port for Zookeeper is 2181. Mesos-DNS will monitor the Zookeeper instances to detect the current leading master.

* `MESOSDNS_ZKDETECTIONTIMEOUT` - Time in seconds for Zookeeper to report a new Mesos leading master. If this threshold is crossed, Mesos-DNS will exit. Default value is `30`.

* `MESOSDNS_MASTERS_###` - All `MESOSDNS_MASTERS_###` are converted to comma separated list with the IP address and port number for the master(s) in the Mesos cluster. Mesos-DNS will automatically find the leading master at any point in order to retrieve state about running tasks. If there is no leading master or the leading master is not responsive, Mesos-DNS will continue serving DNS requests based on stale information about running tasks. The `masters` field is **required**.

* `MESOSDNS_REFRESHSECONDS` - The frequency at which Mesos-DNS updates DNS records based on information retrieved from the Mesos master. The default value is 60 seconds.

* `MESOSDNS_TTL` -  The time to live value for DNS records served by Mesos-DNS, in seconds. It allows caching of the DNS record for a period of time in order to reduce DNS request rate. `MESOSDNS_TTL` should be equal or larger than `MESOSDNS_REFRESHSECONDS`. The default value is 60 seconds.

* `MESOSDNS_DOMAIN` - Is the domain name for the Mesos cluster. The domain name can use characters [a-z, A-Z, 0-9], - if it is not the first or last character of a domain portion, and . as a separator of the textual portions of the domain name. We recommend you avoid valid top-level domain names. The default value is `mesos`.

* `MESOSDNS_PORT` - Is the port number that Mesos-DNS monitors for incoming DNS requests. Requests can be sent over TCP or UDP. We recommend you use port `53` as several applications assume that the DNS server listens to this port. The default value is `53`.

* `MESOSDNS_RESOLVERS_###` - ALL `MESOSDNS_RESOLVERS_###` are converted to a json list with the IP addresses of external DNS servers that Mesos-DNS will contact to resolve any DNS requests outside the domain. We recommend that you list the nameservers specified in the `/etc/resolv.conf` on the server Mesos-DNS is running. Alternatively, you can list 8.8.8.8, which is the Google public DNS address. The resolvers field is **required**.

* `MESOSDNS_TIMEOUT` - Is the timeout threshold, in seconds, for connections and requests to external DNS requests. The default value is 5 seconds.


* `MESOSDNS_HTTPON` -  Is a boolean field that controls whether Mesos-DNS listens for HTTP requests or not. The default value is `true`.

* `MESOSDNS_DNSON` - Is a boolean field that controls whether Mesos-DNS listens for DNS requests or not. The default value is `true`.

* `MESOSDNS_HTTPPORT` -  Is the port number that Mesos-DNS monitors for incoming HTTP requests. The default value is `8123`.

* `MESOSDNS_EXTERNALON` - Is a boolean field that controls whether Mesos-DNS serves requests outside of the Mesos domain. The default value is `true`.

* `MESOSDNS_LISTENER` - It is the IP address of Mesos-DNS. In SOA replies, Mesos-DNS identifies hostname mesos-dns.domain as the primary nameserver for the domain. It uses this IP address in an A record for mesos-dns.domain. The default value is "0.0.0.0", which instructs Mesos-DNS to create an A record for every IP address associated with a network interface on the server that runs the Mesos-DNS process.

* `MESOSDNS_SOAMNAME` - Is the MNAME field in the SOA record for the Mesos domain. It is the primary or master name server. The default value is `ns1.mesos`.

* `MESOSDNS_SOARNAME` - Is the RNAME field in the SOA record for the Mesos domain. The format is `mailbox.domain`, using a `.` instead of `@`. For example, if the email address is `root@ns1.mesos`, the email field should be `root.mesos-dns.mesos`. For details, see the [RFC-1035](http://tools.ietf.org/html/rfc1035#page-18). The default value is `root.ns1.mesos`.

* `MESOSDNS_SOAREFRESH` -  Is the REFRESH field in the SOA record for the Mesos domain. For details, see the [RFC-1035](http://tools.ietf.org/html/rfc1035#page-18). The default value is `60`.

* `MESOSDNS_RETRY` -  Is the RETRY field in the SOA record for the Mesos domain. For details, see the [RFC-1035](http://tools.ietf.org/html/rfc1035#page-18). The default value is `600`.

* `MESOSDNS_EXPIRE` - Is the EXPIRE field in the SOA record for the Mesos domain. For details, see the [RFC-1035](http://tools.ietf.org/html/rfc1035#page-18). The default value is `86400`.

* `MESOSDNS_SOAMINTTL` - Is the minimum TTL field in the SOA record for the Mesos domain. For details, see the [RFC-1035](http://tools.ietf.org/html/rfc1035#page-18). The default value is `60`.

* `MESOSDNS_STATETIMEOUTSECONDS` - The time, in seconds that Mesos-DNS will wait for the Mesos master to respond to it's requests for state.json. The default value is `300`.

* `MESOSDNS_RECURSEON` - Controls if the DNS replies for names in the Mesos domain will indicate that recursion is available. The default value is `true`.

* `MESOSDNS_ENFORCERCF952` - Enables an older stricter set of rules for DNS labels. For more information, see [RFC-952](https://tools.ietf.org/html/rfc952). Default value is `false`.

* `MESOSDNS_IPSOURCES_###` - All `MESOSDNS_IPSOURCES_###` are converted to a json list that define the fallback order of IP sources for task records, sorted by priority. Options include: `host`, `mesos`, `docker`, and `netinfo`.

```
Usage of mesos-dns:
  -alsologtostderr=false: log to standard error as well as files
  -config="config.json": path to config file (json)
  -httptest.serve="": if non-empty, httptest.NewServer serves on this address and blocks
  -log_backtrace_at=:0: when logging hits line file:N, emit a stack trace
  -log_dir="": If non-empty, write log files in this directory
  -logtostderr=false: log to standard error instead of files
  -stderrthreshold=0: logs at or above this threshold go to stderr
  -v=0: log level for V logs
  -version=false: output the version
  -vmodule=: comma-separated list of pattern=N settings for file-filtered logging
  ```


---


### Consul-Template

Provides initial configuration of consul-template. Variables prefixed with `CONSUL_TEMPLATE_` will automatically be passed to the consul-template service at runtime, e.g. `CONSUL_TEMPLATE_SSL_CA_CERT=/etc/consul/certs/ca.crt` becomes `-ssl-ca-cert="/etc/consul/certs/ca.crt"`. If managing the application configuration is handled via file configs, no other variables must be passed at runtime.

#### Consul-Template Environment Variables

##### Defaults

| **Variable**                  | **Default**                           |
|-------------------------------|---------------------------------------|
| `CONSUL_TEMPLATE_CONFIG`      | `/etc/consul/template/conf.d`         |
| `CONSUL_TEMPLATE_SYSLOG`      | `true`                                |
| `SERVICE_CONSUL_TEMPLATE`     |                                       |
| `SERVICE_CONSUL_TEMPLATE_CMD` | `consul-template <CONSUL_TEMPLATE_*>` |


---


### Logrotate

The logrotate script is a small simple script that will either call and execute logrotate on a given interval; or execute a supplied script. This is useful for applications that do not perform their own log cleanup.

#### Logrotate Environment Variables

##### Defaults

| **Variable**                 | **Default**                        |
|------------------------------|------------------------------------|
| `SERVICE_LOGROTATE`          |                                    |
| `SERVICE_LOGROTATE_INTERVAL` | `3600`                             |
| `SERVICE_LOGROTATE_CONFIG`   |                                    |
| `SERVICE_LOGROTATE_SCRIPT`   | `/opt/scripts/purge-mdns-logs.sh`  |
| `SERVICE_LOGROTATE_FORCE`    |                                    |
| `SERVICE_LOGROTATE_VERBOSE`  |                                    |
| `SERVICE_LOGROTATE_DEBUG`    |                                    |
| `SERVICE_LOGROTATE_CMD`      | `/opt/script/logrotate.sh <flags>` |

##### Description

* `SERVICE_LOGROTATE` - Enables or disables the Logrotate service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGROTATE_INTERVAL` - The time in seconds between run of either the logrotate command or the provided logrotate script. Default is set to `3600` or 1 hour in the script itself.

* `SERVICE_LOGROTATE_CONFIG` - The path to the logrotate config file. If neither config or script is provided, it will default to `/etc/logrotate.conf`.

* `SERVICE_LOGROTATE_SCRIPT` - A script that should be executed on the provided interval. Useful to do cleanup of logs for applications that already handle rotation, or if additional processing is required.

* `SERVICE_LOGROTATE_FORCE` - If present, passes the 'force' command to logrotate. Will be ignored if a script is provided.

* `SERVICE_LOGROTATE_VERBOSE` - If present, passes the 'verbose' command to logrotate. Will be ignored if a script is provided.

* `SERVICE_LOGROTATE_DEBUG` - If present, passed the 'debug' command to logrotate. Will be ignored if a script is provided.

* `SERVICE_LOGROTATE_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


##### Logrotate Script Help Text
```
root@ec58ca7459cb:/opt/scripts# ./logrotate.sh --help
logrotate.sh - Small wrapper script for logrotate.
-i | --interval     The interval in seconds that logrotate should run.
-c | --config       Path to the logrotate config.
-s | --script       A script to be executed in place of logrotate.
-f | --force        Forces log rotation.
-v | --verbose      Display verbose output.
-d | --debug        Enable debugging, and implies verbose output. No state file changes.
-h | --help         This usage text.
```

##### Supplied Cleanup Script

The below cleanup script will remove all but the latest 5 rotated logs.
**Note:** This script **WILL** restart the mesos-dns service to trigger log-rotation. This should not impact services.

```bash
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
```

---

### Logstash-Forwarder

Logstash-Forwarder is a lightweight application that collects and forwards logs to a logstash server endpoint for further processing. For more information see the [Logstash-Forwarder](https://github.com/elastic/logstash-forwarder) project.


#### Logstash-Forwarder Environment Variables

##### Defaults

| **Variable**                         | **Default**                                                                            |
|--------------------------------------|----------------------------------------------------------------------------------------|
| `SERVICE_LOGSTASH_FORWARDER`         |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CONF`    | `/opt/logstash-forwarder/mesos-dns.conf`                                               |
| `SERVICE_LOGSTASH_FORWARDER_ADDRESS` |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CERT`    |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CMD`     | `/opt/logstash-forwarder/logstash-fowarder -cofig="${SERVICE_LOGSTASH_FOWARDER_CONF}"` |

##### Description

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_LOGSTASH_FORWARDER_ADDRESS` - The address of the Logstash server.

* `SERVICE_LOGSTASH_FORWARDER_CERT` - The path to the Logstash-Forwarder server certificate.

* `SERVICE_LOGSTASH_FORWARDER_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.

---

### Redpill

Redpill is a small script that performs status checks on services managed through supervisor. In the event of a failed service (FATAL) Redpill optionally runs a cleanup script and then terminates the parent supervisor process.

#### Redpill Environment Variables

##### Defaults

| **Variable**               | **Default** |
|----------------------------|-------------|
| `SERVICE_REDPILL`          |             |
| `SERVICE_REDPILL_MONITOR`  | `mesos-dns` |
| `SERVICE_REDPILL_INTERVAL` |             |
| `SERVICE_REDPILL_CLEANUP`  |             |
| `SERVICE_REDPILL_CMD`      |             |


##### Description

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor. 

* `SERVICE_REDPILL_INTERVAL` - The interval in which Redpill polls supervisor for status checks. (Default for the script is 30 seconds)

* `SERVICE_REDPILL_CLEANUP` - The path to the script that will be executed upon container termination.

* `SERVICE_REDPILL_CMD` - The command that is passed to supervisor. It is dynamically built from the other redpill variables. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


##### Redpill Script Help Text
```
root@c90c98ae31e1:/# /opt/scripts/redpill.sh --help
Redpill - Supervisor status monitor. Terminates the supervisor process if any specified service enters a FATAL state.

-c | --cleanup    Optional path to cleanup script that should be executed upon exit.
-h | --help       This help text.
-i | --interval    Optional interval at which the service check is performed in seconds. (Default: 30)
-s | --service    A comma delimited list of the supervisor service names that should be monitored.
```

---

### Rsyslog
Rsyslog is a high performance log processing daemon. For any modifications to the config, it is best to edit the rsyslog configs directly (`/etc/rsyslog.conf` and `/etc/rsyslog.d/*`).

##### Defaults

| **Variable**                      | **Default**                                      |
|-----------------------------------|--------------------------------------------------|
| `SERVICE_RSYSLOG`                 | `disabled`                                       |
| `SERVICE_RSYSLOG_CONF`            | `/etc/rsyslog.conf`                              |
| `SERVICE_RSYSLOG_CMD`             | `/usr/sbin/rsyslogd -n -f $SERVICE_RSYSLOG_CONF` |

##### Description

* `SERVICE_RSYSLOG` - Enables or disables the rsyslog service. This will automatically be set depending on what other services are enabled. (**Options:** `enabled` or `disabled`)

* `SERVICE_RSYSLOG_CONF` - The path to the rsyslog configuration file.

* `SERVICE_RSYSLOG_CMD` -  The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


---
---

### Troubleshooting

In the event of an issue, the `ENVIRONMENT` variable can be set to `debug` to stop the container from shipping logs and terminating in the event of a fatal error. This will also automatically set the log verbosity to very verbose (log level 2).

For specific issues, please see the Mesos-DNS documentation on [troubleshooting](http://mesosphere.github.io/mesos-dns/docs/faq.html).


