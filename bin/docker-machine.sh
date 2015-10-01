#!/bin/sh

function create_docker_machine () {
  name=$1
  ip=$2
  pub_key=$3

  docker-machine create -d generic \
    --generic-ssh-user core \
    --generic-ssh-key $pub_key \
    --generic-ip-address $ip \
    $name
}
