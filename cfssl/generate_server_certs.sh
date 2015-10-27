#!/bin/sh

# https://coreos.com/os/docs/latest/generate-self-signed-certificates.html

path=$1
ADDRESS=$2
NAME=$3

if [[ $NAME == *"-1"* ]]; then
  ROLE="server"
else
  ROLE="client-server"
fi

# server AND client-server

echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert \
-ca=$path/cfssl/certs/ca.pem \
-ca-key=$path/cfssl/certs/ca-key.pem \
-config=$path/cfssl/certs/ca-config.json \
-profile="$ROLE" \
-hostname="$ADDRESS" - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/$NAME
