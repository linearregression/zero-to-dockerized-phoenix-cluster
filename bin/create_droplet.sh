#!/bin/sh

if [ -n "$1" ]; then
    DROPLET_NAME=$1
else
    DROPLET_NAME=tcore00
fi
FILE_DATA=""

function create_droplet () {
  data=$1
  new_ssh_id=$(cat $ssh_id_file)
  curl -X POST "https://api.digitalocean.com/v2/droplets" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $DO_TOKEN" \
       -d '{"name":"'"$DROPLET_NAME"'",
           "region":"'"$REGION"'",
           "image": "coreos-stable",
           "size":"'"$SIZE"'",
           "ipv6":true,
           "private_networking":true,
           "ssh_keys":["'"$SSH_KEY_ID"'", "'"$new_ssh_id"'"],
           "user_data":"'"$data"'"}'

}

if [[ $DROPLET_NAME == *"-1"* ]]; then
  echo "========================"
  echo "[MASTER : $DROPLET_NAME]"
  echo "========================"
  FILE_DATA=`cat ./master.yml`
  txt=$(create_droplet $FILE_DATA)
  master_id=$(echo $txt | ./JSON.sh -b | egrep '\["droplet","id"\]' | xargs echo | awk '{x=$2}END{print x}')

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
  create_droplet $FILE_DATA
fi
