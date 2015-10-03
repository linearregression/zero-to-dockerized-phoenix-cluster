#!/bin/sh

# https://coreos.com/os/docs/latest/generate-self-signed-certificates.html

export path=$1
export ADDRESS=$2
export NAME=$3

if [[ $NAME == *"-1"* ]]; then
  export ROLE="server"
else
  export ROLE="client-server"
fi

# server AND client-server

echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert \
-ca=$path/cfssl/certs/core.pem \
-ca-key=$path/cfssl/certs/core-key.pem \
-config=$path/cfssl/certs/core-config.json \
-profile="$ROLE" \
-hostname="$ADDRESS" - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/$NAME
