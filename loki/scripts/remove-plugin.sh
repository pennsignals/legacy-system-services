#!/bin/bash

nomad node-drain -enable -self

rm /etc/docker/daemon.json

docker plugin disable penn/loki

docker plugin rm penn/loki

sudo systemctl restart docker

nomad node-drain -disable -self