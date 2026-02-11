#!/bin/bash

echo
echo "COMMAND: ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
echo

echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo

