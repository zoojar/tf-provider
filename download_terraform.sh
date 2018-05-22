#!/bin/bash
TF_VERSION=$1
TF_FILE="terraform_${TF_VERSION}_linux_amd64.zip"
TF_BIN_CACHE_DIR=/tmp
if [ -f "$TF_BIN_CACHE_DIR/$TF_FILE" ]
then
  echo "$TF_FILE exists - not downloading. copying from: $TF_BIN_CACHE_DIR"
  cp $TF_BIN_CACHE_DIR/$TF_FILE .
else
  echo "$TF_FILE does not exist, downloading..."
  wget -k https://releases.hashicorp.com/terraform/${TF_VERSION}/$TF_FILE
  cp -n $TF_FILE $TF_BIN_CACHE_DIR/$TF_FILE
  unzip terraform_${TF_VERSION}_linux_amd64.zip 
fi
