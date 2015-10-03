#!/bin/sh

export NAME=$1
export ROOT_DIR=$2
export ssh_id_file=$3

key_file="$ROOT_DIR/ssh/$NAME.key"
pub_file="$ROOT_DIR/ssh/$NAME.key.pub"

if [ -f key_file ]; then
    rm -f key_file
fi
if [ -f pub_file ]; then
  rm -f pub_file
fi

ssh-keygen -t rsa  -b 4096 -N "" -f $key_file

public_key=$(cat $pub_file)
# echo $public_key
ssh_txt=$(curl -X POST "https://api.digitalocean.com/v2/account/keys" \
               -H 'Content-Type: application/json' \
               -H "Authorization: Bearer $DO_TOKEN" \
               -d '{"name":"'"$NAME"'",
                   "public_key":"'"$public_key"'"}')

SSH_ID=$(echo $ssh_txt | ./JSON.sh -b | egrep '\["ssh_key","id"\]' | xargs echo | awk '{x=$2}END{print x}')
echo $SSH_ID > "$ssh_id_file"
ssh-add $key_file

