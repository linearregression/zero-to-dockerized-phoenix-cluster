#!/bin/sh

if [ -n "$1" ]; then
    DROPLET_NAME=$1
else
    DROPLET_NAME=tcore00
fi

if [[ $DROPLET_NAME == *"-1"* ]]; then
  echo "[MASTER : $DROPLET_NAME]";
  value=`cat ./master.yml`
  curl -X POST "https://api.digitalocean.com/v2/droplets" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $DO_TOKEN" \
       -d '{"name":"'"$DROPLET_NAME"'",
           "region":"'"$REGION"'",
           "image": "coreos-stable",
           "size":"'"$SIZE"'",
           "ipv6":true,
           "private_networking":true,
           "ssh_keys":["'"$SSH_KEY_ID"'"]}'
else
  echo "[NODE: $DROPLET_NAME]";
fi
