#!/bin/sh

if [ -n "$1" ]; then
    DROPLET_NAME=$1
else
    DROPLET_NAME=tcore00
fi
FILE_DATA=""

if [[ $DROPLET_NAME == *"-1"* ]]; then
  echo "========================"
  echo "[MASTER : $DROPLET_NAME]"
  echo "========================"
  FILE_DATA=`cat ./master.yml`

  txt=$(curl -X POST "https://api.digitalocean.com/v2/droplets" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $DO_TOKEN" \
       -d '{"name":"'"$DROPLET_NAME"'",
           "region":"'"$REGION"'",
           "image": "coreos-stable",
           "size":"'"$SIZE"'",
           "ipv6":true,
           "private_networking":true,
           "ssh_keys":["'"$SSH_KEY_ID"'"],
           "user_data":"$FILE_DATA"}')


  master_id=$(echo $txt | ./JSON.sh -b | egrep '\["droplet","id"\]' | xargs echo | awk '{x=$2}END{print x}')


  # info='{"droplet":{"id":7977883,"name":"core-1","memory":4096,"vcpus":2,"disk":60,"locked":true,"status":"new","kernel":null,"created_at":"2015-10-01T17:40:36Z","features":["virtio"],"backup_ids":[],"next_backup_window":null,"snapshot_ids":[],"image":{"id":13750582,"name":"766.4.0 (stable)","distribution":"CoreOS","slug":"coreos-stable","public":true,"regions":["nyc1","sfo1","nyc2","ams2","sgp1","lon1","nyc3","ams3","fra1","tor1"],"created_at":"2015-09-29T17:34:33Z","min_disk_size":20,"type":"snapshot"},"size":{"slug":"4gb","memory":4096,"vcpus":2,"disk":60,"transfer":4.0,"price_monthly":40.0,"price_hourly":0.05952,"regions":["nyc2","ams1","sgp1","lon1","nyc3","ams3","nyc1","ams2","sfo1","fra1","tor1"],"available":true},"size_slug":"4gb","networks": {"v4": [{"ip_address": "104.131.186.241","netmask": "255.255.240.0","gateway": "104.131.176.1","type": "public"}],"v6": [{"ip_address": "2604:A880:0800:0010:0000:0000:031D:2001","netmask": 64,"gateway": "2604:A880:0800:0010:0000:0000:0000:0001","type": "public"}]},"region":{"name":"Singapore 1","slug":"sgp1","sizes":["32gb","16gb","2gb","1gb","4gb","8gb","512mb","64gb","48gb"],"features":["private_networking","backups","ipv6","metadata"],"available":true}}}'
  public_ip=""
  private_ip=""

  while : ; do
    sleep 5;
    info=$(curl -X GET "https://api.digitalocean.com/v2/droplets/${master_id}" \
           -H 'Content-Type: application/json' \
           -H "Authorization: Bearer $DO_TOKEN")
    public_ip=$( echo $info | ./JSON.sh -b | egrep '\["droplet","networks","v4",0,"ip_address"\]' | xargs echo | awk '{x=$2}END{print x}')
    private_ip=$(echo $info | ./JSON.sh -b | egrep '\["droplet","networks","v4",1,"ip_address"\]' | xargs echo | awk '{x=$2}END{print x}')
    echo "~~~~~~~~~~~~~~~~~~~"
    echo "GOT IP $public_ip $private_ip"
    echo "~~~~~~~~~~~~~~~~~~~"

    if [ -n "$public_ip" ] && [ -n "$private_ip" ]; then
      echo $private_ip > "$private_ip_file"
      break
    fi
  done
else
  echo ""
  echo "========================"
  echo "[NODE: $DROPLET_NAME]"
  echo "========================"
  MASTER_PRIVATE_IP=$(cat $private_ip_file)
  FILE_DATA=`cat ./node.yml`
  FILE_DATA=$(echo ${FILE_DATA} | sed "s/MASTER_PRIVATE_IP/${MASTER_PRIVATE_IP}/g")
  curl -X POST "https://api.digitalocean.com/v2/droplets" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $DO_TOKEN" \
       -d '{"name":"'"$DROPLET_NAME"'",
           "region":"'"$REGION"'",
           "image": "coreos-stable",
           "size":"'"$SIZE"'",
           "ipv6":true,
           "private_networking":true,
           "ssh_keys":["'"$SSH_KEY_ID"'"],
           "user_data":"$FILE_DATA"}'
fi


