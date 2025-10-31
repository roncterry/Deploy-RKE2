#!/bin/bash

LPP_INSTALL_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
LPP_IS_DEFAULT_STORAGECLASS="true"

###############################################################################
#   Functions
###############################################################################

deploy_local_path_provisioner() {
  echo "COMMAND: kubectl apply -f ${LPP_INSTALL_URL}"
  kubectl apply -f ${LPP_INSTALL_URL}
  echo

  case ${LPP_IS_DEFAULT_STORAGECLASS} in 
    true)
      echo "COMMAND: kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true"
      kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true
      echo
    ;;
  esac
}

display_storage_classes() {
  echo "-----------------------------------------------------------------------------"
  echo
  echo "COMMAND: kubectl get storageclasses"
  kubectl get storageclasses
  echo

  for STORAGECLASS in $(kubectl get storageclasses | grep -v ^NAME | awk '{ print $1 }')
  do
    echo "-----------------------------------------------------------------------------"
    echo
    echo "COMMAND: kubectl describe storageclasses ${STORAGECLASS}"
    kubectl describe storageclasses ${STORAGECLASS}
    echo 
    echo "-----------------------------------------------------------------------------"
    echo
  done
}

###############################################################################

deploy_local_path_provisioner
display_storage_classes
