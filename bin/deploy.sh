#!/bin/sh
set -e
INPUT_SSH_KEY_ID=0
DROPLET_NAME=0
INPUT_NUM_OF_DROPLETS=0
INPUT_REGION=0
REGION=0
ETCD_TOKEN=0
SIZE=0
DROPLET_SIZE=0
INPUT_DROPLET_SIZE=0
MASTER_PRIVATE_IP=0
key_file=0
pub_file=0
SSH_ID=0

USAGE="Usage: $0 [-k ssh key id] [-t digitalocean v2 token] [-o droplet name prefix] [-n number of droplets] [-e etcd token] [-s droplet size]
Options:
    -k SSH_KEY_ID         SSH KEY ID on digitalocean. you need digitalocean token to get it.
    -r REGION             region
    -t DO_TOKEN           digitalocean api v2 token that has read/write permission
    -o DROPLET_NAME       name prefix for droplets. core => core-1, core-2, core-3
    -n INPUT_NUM          default 3
    -e ETCD_TOKEN         without this option, we will get one by default
    -s DROPLET_SIZE       512mb|1gb|2gb|4gb|8gb|16gb
"

while [ "$#" -gt 0 ]; do
    case $1 in
        -k)
            shift 1
            INPUT_SSH_KEY_ID=$1
            ;;
        -r)
            shift 1
            INPUT_REGION=$1
            ;;
        -t)
            shift 1
            DO_TOKEN=$1
            ;;
        -o)
            shift 1
            DROPLET_NAME=$1
            ;;
        -n)
            shift 1
            INPUT_NUM=$1
            ;;
        -e)
            shift 1
            ETCD_TOKEN=$1
            ;;
        -s)
            shift 1
            DROPLET_SIZE=$1
            ;;
        --help)
            echo "$USAGE"
            exit 0
            ;;
        -h)
            echo "$USAGE"
            exit 0
            ;;
    esac
    shift 1
done

if ! echo $DROPLET_SIZE | grep -qE '512mb|1gb|2gb|4gb|8gb|16gb'; then
    echo "========================="
    echo 'DROPLET_SIZE must be 512mb|1gb|2gb|4gb|8gb|16gb'
    echo "========================="
    echo "Please input your DROPLET_SIZE :"
    read INPUT_DROPLET_SIZE
    export SIZE=$INPUT_DROPLET_SIZE
else
  export SIZE=$DROPLET_SIZE
fi

if [ -z "$DO_TOKEN" ]; then
    echo "Please input your token for Digital Ocean after -t option."
    echo "visit https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2#how-to-generate-a-personal-access-token"
    exit 1
fi

if (test -z "$INPUT_SSH_KEY_ID" ); then
    echo "========================="
    echo "Getting ssh keys from digitalocean"
    echo ""
    curl -X GET -H 'Content-Type: application/json' \
                -H "Authorization: Bearer $DO_TOKEN" \
                "https://api.digitalocean.com/v2/account/keys" | \
    ./JSON.sh -b | grep -E 'id|name'
    echo "========================="
    echo "Please input your ssh key id for CoreOS :"
    read INPUT_SSH_KEY_ID
    export SSH_KEY_ID=$INPUT_SSH_KEY_ID
else
  export SSH_KEY_ID=$INPUT_SSH_KEY_ID
fi

if [ -z "$INPUT_NUM" ]; then
    echo "========================="
    echo 'Number of droplets must be odd. (3, 5, 7 ..)'
    echo "========================="
    echo "Please input number of droplets :"
    read INPUT_NUM_OF_DROPLETS
    export NUM_OF_DROPLETS=$INPUT_NUM_OF_DROPLETS
else
    export NUM_OF_DROPLETS=$INPUT_NUM
fi

if [ -z "$ETCD_TOKEN" ]; then
  export DISCOVERY_URL=`curl https://discovery.etcd.io/new?size=$NUM_OF_DROPLETS`
  echo $DISCOVERY_URL > "./DISCOVERY_URL"
  echo "saved etcd discovery url at ./bin/DISCOVERY_URL"
  echo "$DISCOVERY_URL"
else
  export DISCOVERY_URL="https://discovery.etcd.io/$ETCD_TOKEN"
  echo "$DISCOVERY_URL"
fi

if [ -z "$INPUT_REGION" ]; then
    echo "========================="
    echo "Getting regions from digitalocean"
    echo ""
    curl -X GET -H 'Content-Type: application/json' \
                -H "Authorization: Bearer $DO_TOKEN" \
                "https://api.digitalocean.com/v2/regions" | \
    ./JSON.sh -b | grep -E 'slug'
    echo "========================="
    echo "Please input your region :"
    read INPUT_REGION
    export REGION=$INPUT_REGION
else
    export REGION=$INPUT_REGION
fi

if [ -z "$DROPLET_NAME" ]; then
    DROPLET_NAME=core
    export DROPLET_NAME=$DROPLET_NAME
fi


NAME_PREFIX=$DROPLET_NAME
export ROOT_DIR=`echo ${PWD/bin//}`
export private_ip_file=$(mktemp "./private_ip.XXXXXX")
export ssh_id_file=$(mktemp "$ROOT_DIR/ssh/ssh_id.XXXXXX")


echo "========================="
echo "Creating ssh and upload to digital ocean"
echo "========================="
../ssh/ssh.sh "$NAME_PREFIX" $ROOT_DIR $ssh_id_file

echo "========================="
echo "Creating base certs"
echo "========================="
../cfssl/generate_certs.sh $ROOT_DIR

for i in `seq $NUM_OF_DROPLETS`; do
  /bin/bash ./create_droplet.sh "$NAME_PREFIX-$i" "../ssh/$NAME_PREFIX.key" $ROOT_DIR
done

rm $private_ip_file
rm $ssh_id_file
