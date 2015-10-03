#!/bin/sh

DROPLET_NAME=$1
SSH_KEY=$2
ROOT_DIR=$3
ROOT_DIR=`echo ${ROOT_DIR/\/\/\//\/}`
FILE_DATA=""

function cmd () {
  remote=$1
  todo=$2
  ssh -o StrictHostKeyChecking=no \
      -i "$SSH_KEY" core@$remote $todo
}

function upload_certs () {
  ip=$1
  sleep 10;

  DOCKER_CA_PEM="core.pem"
  DOCKER_SERVER_PEM="$DROPLET_NAME.pem"
  DOCKER_SERVER_KEY_PEM="$DROPLET_NAME-key.pem"
  ROOT_DIR=`echo ${ROOT_DIR/\/\//\/}`

  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/cfssl/certs/$DOCKER_SERVER_PEM" core@$ip:
  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/cfssl/certs/$DOCKER_SERVER_KEY_PEM" core@$ip:
  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/cfssl/certs/$DOCKER_CA_PEM" core@$ip:

  cmd $ip "sudo mkdir /etc/docker/"

  cmd $ip "sudo mv $DOCKER_SERVER_PEM /etc/docker/"
  cmd $ip "sudo mv $DOCKER_SERVER_KEY_PEM /etc/docker/"
  cmd $ip "sudo mv $DOCKER_CA_PEM /etc/docker/"

  cmd $ip "sudo chown root:root /etc/docker/$DOCKER_SERVER_PEM"
  cmd $ip "sudo chown root:root /etc/docker/$DOCKER_SERVER_KEY_PEM"
  cmd $ip "sudo chown root:root /etc/docker/$DOCKER_CA_PEM"

  cmd $ip "sudo chmod 0600 /etc/docker/$DOCKER_SERVER_KEY_PEM"

  cmd $ip "sudo systemctl restart docker.service"

  # TODO
  #
  # Copy certs to docker-machine dir with a json template
  # Make sure docker-machine sets docker env properly.
  #
  # export DOCKER_TLS_VERIFY="1"
  # export DOCKER_HOST="tcp://192.168.99.100:2376"
  # export DOCKER_CERT_PATH="~/.docker/machine/machines/dev"
  # export DOCKER_MACHINE_NAME="dev"
  #
  # mkdir ~/.docker
  # chmod 700 ~/.docker
  # cd ~/.docker
  # cp -p ~/cfssl/ca.pem ca.pem
  # cp -p ~/cfssl/client.pem cert.pem
  # cp -p ~/cfssl/client-key.pem key.pem

}

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

function work_on_droplet () {
  fdata=$1
  check_master=$2
  txt=$(create_droplet $fdata)
  id=$(echo $txt | ./JSON.sh -b | egrep '\["droplet","id"\]' | xargs echo | awk '{x=$2}END{print x}')

  public_ip=""
  private_ip=""

  while : ; do
    sleep 5;
    info=$(curl -X GET "https://api.digitalocean.com/v2/droplets/${id}" \
           -H 'Content-Type: application/json' \
           -H "Authorization: Bearer $DO_TOKEN")
    private_ip=$( echo $info | ./JSON.sh -b | egrep '\["droplet","networks","v4",0,"ip_address"\]' | xargs echo | awk '{x=$2}END{print x}')
    public_ip=$(echo $info | ./JSON.sh -b | egrep '\["droplet","networks","v4",1,"ip_address"\]' | xargs echo | awk '{x=$2}END{print x}')
    echo "~~~~~~~~~~~~~~~~~~~"
    echo "GOT IP $public_ip $private_ip"
    echo "~~~~~~~~~~~~~~~~~~~"

    if [ -n "$public_ip" ] && [ -n "$private_ip" ]; then
      if [ -n "$check_master" ] ; then
        echo $private_ip > "$private_ip_file"
      fi
      $ROOT_DIR/cfssl/generate_server_certs.sh "$ROOT_DIR" "$public_ip, $DROPLET_NAME.local, $DROPLET_NAME" "$DROPLET_NAME"
      upload_certs "$public_ip"
      break
    fi
  done
}

DISCOVERY_URL=`cat ./DISCOVERY_URL`
DISCOVERY_URL2=`echo ${DISCOVERY_URL/https\:\/\//https\\\:\\\/\\\/}`
DISCOVERY_URL3=`echo ${DISCOVERY_URL2/.io\//.io\\\/}`

if [[ $DROPLET_NAME == *"-1"* ]]; then
  echo "========================"
  echo "[MASTER : $DROPLET_NAME]"
  echo "========================"
  FILE_DATA=`cat ./master.yml`
  FILE_DATA=$(echo ${FILE_DATA} | sed "s/DISCOVERY_URL/${DISCOVERY_URL3}/g")
  work_on_droplet FILE_DATA "master"
else
  echo ""
  echo "========================"
  echo "[NODE: $DROPLET_NAME]"
  echo "========================"
  MASTER_PRIVATE_IP=$(cat $private_ip_file)
  FILE_DATA=`cat ./node.yml`
  FILE_DATA=$(echo ${FILE_DATA} | sed "s/MASTER_PRIVATE_IP/${MASTER_PRIVATE_IP}/g")
  FILE_DATA=$(echo ${FILE_DATA} | sed "s/DISCOVERY_URL/${DISCOVERY_URL3}/g")
  work_on_droplet FILE_DATA
fi
