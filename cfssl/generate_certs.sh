#!/bin/sh

# https://coreos.com/os/docs/latest/generate-self-signed-certificates.html

path=$1

#Generate CA and certificates
echo '{"CN":"CORE","key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert -initca - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/core -

template=`cat $path/cfssl/ca-config-template.json`
echo ${template} > $path/cfssl/certs/core-config.json

#Verify data
# openssl x509 -in ca.pem -text -noout
# openssl x509 -in server.pem -text -noout
# openssl x509 -in client.pem -text -noout

# client
echo '{"CN":"client","hosts":[""],"key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert \
-ca=$path/cfssl/certs/core.pem \
-ca-key=$path/cfssl/certs/core-key.pem \
-config=$path/cfssl/certs/core-config.json \
-profile=client - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/client


