#!/bin/bash

LPP_INSTALL_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

echo "COMMAND: kubectl apply -f ${LPP_INSTALL_URL}"
kubectl apply -f ${LPP_INSTALL_URL}

