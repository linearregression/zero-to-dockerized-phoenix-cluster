#!/bin/sh

export NAME=$1
export ROOT_DIR=$2
export ssh_id_file=$3

key_file="$ROOT_DIR/ssh/$NAME.key"
pub_file="$ROOT_DIR/ssh/$NAME.key.pub"
ed25519_file="$ROOT_DIR/ssh/ssh_host_ed25519_key"
host_rsa_file="$ROOT_DIR/ssh/ssh_host_rsa_key"
moduli_all="$ROOT_DIR/ssh/moduli.all"
moduli_safe="$ROOT_DIR/ssh/moduli.safe"

if [ -f "$key_file" ]; then
    rm -f "$key_file"
fi
if [ -f "$pub_file" ]; then
  rm -f "$pub_file"
fi

if [ -f "$ed25519_file" ]; then
  rm -f "$ed25519_file"
fi

if [ -f "$host_rsa_file" ]; then
  rm -f "$host_rsa_file"
fi

ssh-keygen -t ed25519 -N "" -f $ed25519_file  < /dev/null
ssh-keygen -t rsa -b 4096 -N ""  -f $host_rsa_file  < /dev/null

# not going to delete these.
# because it takes too much time to generate.
if [ -f "$moduli_all" ]; then
  echo "moduli_all found."
else
  ssh-keygen -b 4096 -G $moduli_all
fi

if [ -f "$moduli_safe" ]; then
  echo "moduli_safe found."
else
  ssh-keygen -T $moduli_safe -f $moduli_all
fi

ssh-keygen -t rsa  -o -a 100 -b 4096 -N "" -f $key_file

public_key=$(cat $pub_file)
# echo $public_key

ssh_txt=$(curl -X POST "https://api.digitalocean.com/v2/account/keys" \
               -H 'Content-Type: application/json' \
               -H "Authorization: Bearer $DO_TOKEN" \
               -d '{"name":"'"$NAME"'",
                   "public_key":"'"$public_key"'"}')

SSH_ID=$(echo $ssh_txt | $ROOT_DIR/bin/JSON.sh -b | egrep '\["ssh_key","id"\]' | xargs echo | awk '{x=$2}END{print x}')
echo $SSH_ID > "$ssh_id_file"
ssh-add $key_file

