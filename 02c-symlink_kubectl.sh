#!/bin/bash

CONFIG_FILE=deploy_rke2.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  K8S_DISTRO=rke2
  CLUSTER_NAME=c01
  DOMAIN_NAME=example.com
fi

if [ -s /usr/local/bin/kubectl ]
then
  rm /usr/local/bin/kubectl
fi

echo
echo "COMMAND: ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
echo

echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo

