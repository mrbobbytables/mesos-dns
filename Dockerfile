################################################################################
# mesos-dns:1.0.0
# Date: 9/27/2015
# Mesos-DNS Version: v0.1.2
#
# Description:
# Provides DNS for almost all services hosted in Mesos. It has not had a new 
# version released since 4/16/2015, and multiple bug-fixes added to master
# since. 
################################################################################

FROM mrbobbytables/ubuntu-base:1.0.0
MAINTAINER Bob Killen / killen.bob@gmail.com / @mrbobbytables

ENV VERSION_MESOSDNS=v0.1.2

RUN apt-get update                 \
 && export GOROOT=/opt/go          \
 && export GOPATH=/opt/go/gopkg    \
 && export PATH=$PATH:/opt/go/bin:/opt/go/gopkg/bin  \
 && apt-get -y install    \
    git                   \
    make                  \
    wget                  \
 && wget -P /tmp https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz  \
 && tar -xvzf /tmp/go1.4.2.linux-amd64.tar.gz -C /opt/  \
 && go get github.com/tools/godep                       \
 && go get github.com/mesosphere/mesos-dns              \
 && cd $GOPATH/src/github.com/mesosphere/mesos-dns      \
 && git checkout $VERSION_MESOSDNS  \
 && godep get                       \
 && make all                        \
 && cp $GOPATH/bin/mesos-dns /usr/local/bin/mesos-dns  \
 && mkdir -p /etc/mesos-dns      \
 && mkdir -p /var/log/mesos-dns  \
 && apt-get -y purge             \
   git                           \
   make                          \
   wget                          \
 && rm -rf /opt/go               \
 && apt-get -y autoremove        \
 && apt-get -y clean             \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./skel /

RUN chmod +x ./init.sh  \
 && chown -R logstash-forwarder:logstash-forwarder /opt/logstash-forwarder

EXPOSE 53 8123

CMD ["./init.sh"]
