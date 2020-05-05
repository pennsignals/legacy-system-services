#!/bin/bash


read -r -d '' DAEMON_JSON << EOM
{
    "debug" : true,
    "log-driver": "penn/loki",
    "log-opts": {
        "loki-url": "http://172.16.1.102:3100/loki/api/v1/push",
	    "loki-retries": "5",
        "loki-batch-size": "400",
        "loki-pipeline-stage-file": "/tmp/docker-pipeline.yml",
        "loki-external-labels": "job=docker-loki,container_name={{.Name}},image_name={{.ImageName}}"
    }
}
EOM

nomad node-drain -enable -self

sudo sh -c 'echo $DAEMON_JSON > /etc/docker/daemon.json'

docker plugin upgrade penn/loki darrylmendillo/loki-docker-driver:0.0.5

sudo sysytemctl restart docker

nomad node-drain -disable -self