#!/bin/bash

read -r -d '' DAEMON_JSON << EOM
{
    "debug" : true,
    "log-driver": "penn/loki",
    "log-opts": {
        "loki-url": "http://170.166.23.4:3100/loki/api/v1/push",
	    "loki-retries": "5",
        "loki-batch-size": "400",
        "loki-pipeline-stage-file": "/tmp/docker-pipeline.yml",
        "loki-external-labels": "job=docker-loki,container_name={{.Name}},image_name={{.ImageName}}"
    }
}
EOM

sudo nomad node-drain -enable -self

echo "$DAEMON_JSON" > /etc/docker/daemon.json

docker plugin disable penn/loki
docker plugin upgrade --grant-all-permissions penn/loki darrylmendillo/loki-docker-driver:0.0.5 
docker plugin enable penn/loki

sudo systemctl restart docker

sudo nomad node-drain -disable -self