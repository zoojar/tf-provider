#!/bin/bash
TF_VERSION=$1
TF_FILE="terraform_${TF_VERSION}_linux_amd64.zip"
if [ -f "$TF_FILE" ]
then
  echo "$TF_FILE exists - not downloading."
else
  echo "$TF_FILE does not exist, downloading..."
  wget -k https://releases.hashicorp.com/terraform/${TF_VERSION}/$TF_FILE
  unzip terraform_${TF_VERSION}_linux_amd64.zip 
fi
