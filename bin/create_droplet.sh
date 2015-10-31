#!/bin/sh
set -e

DROPLET_NAME=$1
SSH_KEY=$2
ROOT_DIR=$3
TECH_VERSION=$4

ROOT_DIR=`echo ${ROOT_DIR/\/\/\//\/}`
FILE_DATA=""
USER_HOME=$(eval echo ~${SUDO_USER})

#============================================
#  functions for uploading files
#============================================

function cmd () {
  remote=$1
  todo=$2
  ssh  -o StrictHostKeyChecking=no -i "$SSH_KEY" core@$remote $todo
}

function get_leader_config () {
  MASTER_PRIVATE_IP=$1

  LEADER_CONFIG=`cat ./leader`
  LEADER_CONFIG=$(echo ${LEADER_CONFIG} | sed "s/MASTER_PRIVATE_IP/${MASTER_PRIVATE_IP}/g")

  echo $LEADER_CONFIG
}

function get_proxy_config () {
  MASTER_PRIVATE_IP=$1

  if [[ "$TECH_VERSION" == "edge" ]] ; then
    KUBERNETES_VERSION="V1.2..0-alpha.2"
  else
    KUBERNETES_VERSION="v1.0.6"
  fi

  PROXY_CONFIG=`cat ./kube-proxy.yml`
  PROXY_CONFIG=$(echo ${PROXY_CONFIG} | sed "s/KUBERNETES_VERSION/${KUBERNETES_VERSION}/g")
  PROXY_CONFIG=$(echo ${PROXY_CONFIG} | sed "s/MASTER_PRIVATE_IP/${MASTER_PRIVATE_IP}/g")

  echo $PROXY_CONFIG
}

function get_kube_config () {
  if [[ "$TECH_VERSION" == "edge" ]] ; then
    KUBERNETES_VERSION="V1.2.0-alpha.2"
  else
    KUBERNETES_VERSION="v1.0.6"
  fi

  KUBE_CONFIG=`cat ./kubeconfig.yml`
  KUBE_CONFIG=$(echo ${KUBE_CONFIG} | sed "s/KUBERNETES_VERSION/${KUBERNETES_VERSION}/g")

  echo $KUBE_CONFIG
}

function upload_ssh_files () {
  ip=$1

  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/ssh/moduli.safe" core@$ip:
  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/ssh/ssh_host_ed25519_key" core@$ip:
  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/ssh/ssh_host_rsa_key" core@$ip:

  cmd $ip "sudo mv moduli.safe /etc/ssh/moduli"
  cmd $ip "sudo mv ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key"
  cmd $ip "sudo mv ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key"

  echo $(sed  '/$ip/ d' ~/.ssh/known_hosts) > ~/.ssh/known_hosts

  cmd $ip "sudo chown root:root /etc/ssh/moduli"
  cmd $ip "sudo chown root:root /etc/ssh/ssh_host_ed25519_key"
  cmd $ip "sudo chown root:root /etc/ssh/ssh_host_rsa_key"

  cmd $ip "sudo systemctl restart sshd.service"
  echo $(sed  '/$ip/ d' ~/.ssh/known_hosts) > ~/.ssh/known_hosts
}

function upload_certs () {
  ip=$1
  ROOT_DIR=`echo ${ROOT_DIR/\/\//\/}`
  sleep 10;

  if [[ $DROPLET_NAME == *"-1"* ]]; then
    S_ROLE="server"
  else
    S_ROLE="client-server"
  fi

  SERVER_PEM="$DROPLET_NAME.pem"
  SERVER_KEY_PEM="$DROPLET_NAME-key.pem"
  CA_PEM="ca.pem"

  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/cfssl/certs/$SERVER_PEM" core@$ip:
  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/cfssl/certs/$SERVER_KEY_PEM" core@$ip:
  scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$ROOT_DIR/cfssl/certs/$CA_PEM" core@$ip:

  # docker tls related files
  cmd $ip "sudo mkdir -p /etc/kubernetes/ssl"

  cmd $ip "sudo mv $SERVER_PEM /etc/kubernetes/ssl/server.pem"
  cmd $ip "sudo mv $SERVER_KEY_PEM /etc/kubernetes/ssl/server-key.pem"
  cmd $ip "sudo mv $CA_PEM /etc/kubernetes/ssl/ca.pem"
  cmd $ip "sudo chown -R root:root /etc/kubernetes/ssl/"
  cmd $ip "sudo chmod 0600 /etc/kubernetes/ssl/*"

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

#============================================
#  function for changing yml files
#============================================

function change_yml_file () {
  check_master=$1

  if [[ "$check_master" == "master" ]] ; then
    YML_FILE=`cat ./master.yml`
  else
    YML_FILE=`cat ./node.yml`
    MASTER_PRIVATE_IP=$(cat $private_ip_file)
    YML_FILE=$(echo ${YML_FILE} | sed "s/MASTER_PRIVATE_IP/${MASTER_PRIVATE_IP}/g")
  fi

  if [[ "$TECH_VERSION" == "edge" ]] ; then
    KUBERNETES_VERSION="V1.2..0-alpha.2"
  else
    KUBERNETES_VERSION="v1.0.6"
  fi

  KUBE_RELEASE_TARBALL_URL="https://github.com/kubernetes/kubernetes/releases/download/${KUBERNETES_VERSION}/kubernetes.tar.gz"
  DOCKER_CFG=`cat $USER_HOME/.docker/config.json`
  DISCOVERY_URL=`cat $ROOT_DIR/bin/DISCOVERY_URL`
  DISCOVERY_URL2=`echo ${DISCOVERY_URL/https\:\/\//https\\\:\\\/\\\/}`
  DISCOVERY_URL3=`echo ${DISCOVERY_URL2/.io\//.io\\\/}`

  KUBE_CONFIG=$(get_kube_config)
  PROXY_CONFIG=$(get_proxy_config $MASTER_PRIVATE_IP)
  LEADER_CONFIG=$(get_leader_config $check_master $MASTER_PRIVATE_IP)


  YML_FILE=$(echo ${YML_FILE} | sed "s/DISCOVERY_URL/${DISCOVERY_URL3}/g")
  YML_FILE=$(echo ${YML_FILE} | sed "s/DOCKER_CONFIG_DATA/${DOCKER_CFG}/g")

  YML_FILE=$(echo ${YML_FILE} | sed "s/KUBE_CONFIG_DATA/${KUBE_CONFIG}/g")
  YML_FILE=$(echo ${YML_FILE} | sed "s/PROXY_CONFIG_DATA/${PROXY_CONFIG}/g")
  YML_FILE=$(echo ${YML_FILE} | sed "s/LEADER_CONFIG_DATA/${LEADER_CONFIG}/g")

  echo $YML_FILE
}

#============================================
#  Calling cloud server api to create instances
#============================================

function create_droplet () {
  data=$1
  new_ssh_id=$(cat $ssh_id_file)

  if [[ "$TECH_VERSION" == "edge" ]] ; then
    COREOS_IMAGE="coreos-alpha"
  else
    COREOS_IMAGE="coreos-stable"
  fi

  curl -X POST "https://api.digitalocean.com/v2/droplets" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $DO_TOKEN" \
       -d '{"name":"'"$DROPLET_NAME"'",
           "region":"'"$REGION"'",
           "image": "'"$COREOS_IMAGE"'",
           "size":"'"$SIZE"'",
           "ipv6":true,
           "private_networking":true,
           "ssh_keys":["'"$SSH_KEY_ID"'", "'"$new_ssh_id"'"],
           "user_data":"'"$data"'"}'
}

function work_on_droplet () {
  fdata=$1
  check_master=$2
  mdata=$3
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
    echo "~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Public IP: $public_ip"
    echo "Private IP: $private_ip"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~"

    if [ -n "$public_ip" ] && [ -n "$private_ip" ]; then
      if [[ "$check_master" == "master" ]] ; then
        echo $private_ip > "$private_ip_file"
      fi
      $ROOT_DIR/cfssl/generate_server_certs.sh "$ROOT_DIR" "$public_ip", "$DROPLET_NAME"
      upload_certs "$public_ip"
      upload_ssh_files "$public_ip"
      break
    fi
  done
}

#============================================
#  Master / Minion
#============================================

if [[ $DROPLET_NAME == *"-1"* ]]; then
  echo "========================"
  echo "[MASTER : $DROPLET_NAME]"
  echo "========================"
  FILE_DATA=$(change_yml_file "master")
  work_on_droplet FILE_DATA "master"
else
  echo ""
  echo "========================"
  echo "[NODE: $DROPLET_NAME]"
  echo "========================"
  FILE_DATA=$(change_yml_file "node")
  work_on_droplet FILE_DATA "node"
fi
