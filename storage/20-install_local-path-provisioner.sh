#!/bin/bash

##############################################################################
# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_storage.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  LPP_MANIFEST_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
  LPP_IS_DEFAULT_STORAGECLASS="true"
fi

LICENSES_FILE=../authentication_and_licenses.cfg

##############################################################################

check_for_kubectl() {
  if ! echo $* | grep -q force
  then
   if ! which kubectl > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the kubectl command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

##############################################################################


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

check_for_kubectl
deploy_local_path_provisioner
display_storage_classes
