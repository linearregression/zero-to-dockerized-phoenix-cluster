#!/bin/sh

# https://coreos.com/os/docs/latest/generate-self-signed-certificates.html

path=$1

#Generate CA and certificates
echo '{"CN":"CA","key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert -initca - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/ca -

template=`cat $path/cfssl/ca-config-template.json`
echo ${template} > $path/cfssl/certs/ca-config.json

#Verify data
# openssl x509 -in ca.pem -text -noout
# openssl x509 -in server.pem -text -noout
# openssl x509 -in client.pem -text -noout

# client
echo '{"CN":"client","hosts":[""],"key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert \
-ca=$path/cfssl/certs/ca.pem \
-ca-key=$path/cfssl/certs/ca-key.pem \
-config=$path/cfssl/certs/ca-config.json \
-profile=client - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/client


