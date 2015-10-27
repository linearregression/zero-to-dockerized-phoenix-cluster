#!/bin/sh
set -e

# https://coreos.com/os/docs/latest/generate-self-signed-certificates.html
#
# we are going to generate admin, ca certs first.
# and by using ca, we generate server, client-server, client role certs
# generating server and client-server roles certs is called
# in crate_droplet.sh - work_on_droplet ()
#
path=$1
path=`echo ${path/\/\/\//\/}`

#=======================================
# Generate CA and certificates
#=======================================
echo '{"CN":"ca","key":{"algo":"rsa","size":4096}}' | \
  $path/cfssl/cfssl gencert -initca - | \
  $path/cfssl/cfssljson -bare $path/cfssl/certs/ca -

template=`cat $path/cfssl/ca-config-template.json`
echo ${template} > $path/cfssl/certs/ca-config.json

#=======================================
# Verify data
#=======================================
# openssl x509 -in ca.pem -text -noout
# openssl x509 -in server.pem -text -noout
# openssl x509 -in client.pem -text -noout

#=======================================
# For kubernetes admin
#=======================================
echo '{"CN":"admin","key":{"algo":"rsa","size":4096}}' | \
  $path/cfssl/cfssl gencert -initca - | \
  $path/cfssl/cfssljson -bare $path/cfssl/certs/admin -

#=======================================
# client
#=======================================
echo '{"CN":"client","hosts":[""],"key":{"algo":"rsa","size":4096}}' | \
$path/cfssl/cfssl gencert \
-ca=$path/cfssl/certs/ca.pem \
-ca-key=$path/cfssl/certs/ca-key.pem \
-config=$path/cfssl/certs/ca-config.json \
-profile=client - | \
$path/cfssl/cfssljson -bare $path/cfssl/certs/client
