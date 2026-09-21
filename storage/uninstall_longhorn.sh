#!/bin/bash

. deploy_storage.yaml

LH_INSTALLED_NAMESPACE=$(kubectl get daemonsets -A | grep longhorn-manager | awk '{ print $1 }')
LH_HELM_RELEASE_NAME=$(helm -n ${LH_INSTALLED_NAMESPACE} list | tail -n 1 | awk '{ print $1 }')

echo
echo "Removing Longhorn for the cluster ..."
echo

echo "COMMAND: kubectl -n ${LH_INSTALLED_NAMESPACE} patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag"
kubectl -n ${LH_INSTALLED_NAMESPACE} patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag
echo

echo "COMMAND: helm --namespace ${LH_INSTALLED_NAMESPACE} uninstall ${LH_HELM_RELEASE_NAME}"
helm --namespace ${LH_INSTALLED_NAMESPACE} uninstall ${LH_HELM_RELEASE_NAME}
echo

echo ""COMMAND: ubectl delete namespace ${LH_INSTALLED_NAMESPACE}"
kubectl delete namespace ${LH_INSTALLED_NAMESPACE}
echo
