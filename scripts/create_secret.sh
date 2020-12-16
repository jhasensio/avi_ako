#!/bin/bash
# Param 1 = name Param 2 = CN

if [[ $# -ne 2 ]] ; then
    echo 'Usage: create-secret.sh friendly_name subject'
    echo " where friendly_name = name to create outputfiles"
    echo
    echo "   Example:"
    echo -e "\033[1;33m"./create-secret.sh my-site my-site.example.com"\033[0m"
    echo
    echo " will create:"
    echo "   my-site.key as private key file"
    echo "   my-site.crt as public x509 file with my-site.example.com as subject"
    echo "   my-site-secret as kubectl secret in default namespace"
    exit 0
fi

PRIVATE=$1.key
PUBLIC=$1.crt
CSR=$1.csr

openssl ecparam -name prime256v1 -genkey -noout -out $PRIVATE
echo -e "\033[1;33m      Step 1.- EC Prime256 v1 private key generated and saved as "$1".key\033[0m"
echo
openssl req -new -key $PRIVATE -out $CSR -subj "/CN=$2"
echo -e "\033[1;33m      Step 2.- Certificate Signing Request created for CN="$2"\033[0m"
echo
openssl x509 -req -days 365 -in $CSR -signkey $PRIVATE -out $PUBLIC
echo -e "\033[1;33m      Step 3.- X.509 certificated created for 365 days and stored as "$1".crt\033[0m"
echo
kubectl create secret tls $1-secret --cert=$PUBLIC --key=$PRIVATE
echo -e "\033[1;33m      Step 4.- A TLS secret named "$1"-secret has been created in current context and default namespace\033[0m"
echo
kubectl describe secret $1-secret
