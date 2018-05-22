#!/bin/bash
TF_VERSION=$1
TF_FILE="terraform_${TF_VERSION}_linux_amd64.zip"
TF_BIN_CACHE_DIR=/tmp

if [ -f "${TF_BIN_CACHE_DIR}/${TF_FILE}" ]
then
  echo "${TF_FILE} exists - not downloading. copying from: ${TF_BIN_CACHE_DIR}"
  cp ${TF_BIN_CACHE_DIR}/${TF_FILE} .
fi

#download & check sha256sum:
wget -k https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS
if ! cat terraform_${TF_VERSION}_SHA256SUMS | grep $TF_FILE | sha256sum -c ; then 
  wget -k https://releases.hashicorp.com/terraform/${TF_VERSION}/${TF_FILE}
  #replace cached file:
  yes | cp $TF_FILE ${TF_BIN_CACHE_DIR}/${TF_FILE}
fi

unzip $TF_FILE
