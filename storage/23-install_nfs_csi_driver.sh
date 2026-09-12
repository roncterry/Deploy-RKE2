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
  IMAGE_PULL_SECRET_NAME=application-collection

  NFS_CSI_DRIVER_HELM_REPO_URL="https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  NFS_CSI_DRIVER_HELM_CHART=
  NFS_CSI_SERVER_NAME=
  NFS_CSI_SERVER_ADDRESS=
  NFS_CSI_SHARE_PATH=
  NFS_CSI_ALLOW_VOLUME_EXPANSION=true
  NFS_CSI_MOUNT_OPTIONS="nfsvers=4.1"
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

check_for_helm() {
  if ! echo $* | grep -q force
  then
   if ! which helm > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the helm command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

CUSTOM_OVERRIDES_FILE=nfs_csi_custom_overrides.yaml

NFS_CSI_STORAGECLASS_MANIFEST=storageclass-nfs-${NFS_CSI_SERVER_NAME}.yaml

##############################################################################


###############################################################################
#   Functions
###############################################################################

write_out_longhorn_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo

  if ! [ -z ${NFS_CSI_DRIVER_HELM_CHART} ]
  then
    echo "global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}" > ${CUSTOM_OVERRIDES_FILE}
  else
    echo "" > ${CUSTOM_OVERRIDES_FILE}
  fi
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

write_out_nfs_storageclass_manifest() {
  echo "apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi-${NFS_CSI_SERVER_NAME}
provisioner: nfs.csi.k8s.io
parameters:
  server: ${NFS_CSI_SERVER_ADDRESS}
  share: ${NFS_CSI_SHARE_PATH}
reclaimPolicy: ${NFS_CSI_RECLAIM_POLICY}
volumeBindingMode: ${NFS_CSI_VOLUME_BINDING_MODE}
allowVolumeExpansion: ${NFS_CSI_ALLOW_VOLUME_EXPANSION}
mountOptions:
  - ${NFS_CSI_MOUNT_OPTIONS}" > ${NFS_CSI_STORAGECLASS_MANIFEST}
}

display_nfs_storageclass_manifest() {
  echo
  cat ${NFS_CSI_STORAGECLASS_MANIFEST}
  echo
}

deploy_csi_driver_nfs() {
  if ! [ -z ${NFS_CSI_VERSION} ]
  then
    local NFS_CSI_VER_ARG="--version ${NFS_CSI_VERSION}"
  fi

  if [ -z ${NFS_CSI_DRIVER_HELM_CHART} ]
  then
    if ! helm repo list | grep -q csi-driver-nfs
    then
      echo "COMMAND: helm repo add csi-driver-nfs ${NFS_CSI_DRIVER_HELM_REPO_URL}"
      helm repo add csi-driver-nfs ${NFS_CSI_DRIVER_HELM_REPO_URL}
    fi

    echo "COMMAND: helm repo update"
    helm repo update
    echo

    if [ -e ${CUSTOM_OVERRIDES_FILE} ]
    then 
      echo "COMMAND: helm upgrade --install csi-driver-nfs --namespace ${NFS_CSI_DRIVER_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} csi-driver-nfs/csi-driver-nfs ${NFS_CSI_VER_ARG}"
      helm upgrade --install csi-driver-nfs --namespace ${NFS_CSI_DRIVER_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} csi-driver-nfs/csi-driver-nfs ${NFS_CSI_VER_ARG}
    else
      echo "COMMAND: helm upgrade --install csi-driver-nfs --namespace ${NFS_CSI_DRIVER_NAMESPACE} --create-namespace csi-driver-nfs/csi-driver-nfs ${NFS_CSI_VER_ARG}"
      helm upgrade --install csi-driver-nfs --namespace ${NFS_CSI_DRIVER_NAMESPACE} --create-namespace csi-driver-nfs/csi-driver-nfs ${NFS_CSI_VER_ARG}
    fi
    echo
 
    echo "COMMAND: kubectl -n ${NFS_CSINAMESPACE} rollout status deploy/csi-driver-nfs"
    kubectl -n ${NFS_CSINAMESPACE} rollout status deploy/csi-driver-nfs
    echo
  else
    log_into_app_collection
    create_app_collection_secret

    echo "COMMAND: helm upgrade --install csi-driver-nfs ${NFS_CSI_DRIVER_HELM_CHART} --namespace ${NFS_CSI_DRIVER_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} -f ${CUSTOM_OVERRIDES_FILE} ${NFS_CSI_VER_ARG}"
    helm upgrade --install csi-driver-nfs ${NFS_CSI_DRIVER_HELM_CHART} --namespace ${NFS_CSI_DRIVER_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} -f ${CUSTOM_OVERRIDES_FILE} ${NFS_CSI_VER_ARG}
  fi
}

create_csi_driver_nfs_storageclss() {
  echo "COMMAND: kubectl apply -f ${NFS_CSI_STORAGECLASS_MANIFEST}"
  kubectl apply -f ${NFS_CSI_STORAGECLASS_MANIFEST}
  echo
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

case ${1} in
  manifest_only)
    write_out_nfs_storageclass_manifest
    display_nfs_storageclass_manifest
    exit
  ;;
  custom_overrides_only)
    write_out_longhorn_custom_overrides_file
    display_custom_overrides_file
    exit
  ;;
esac

check_for_kubectl
check_for_helm

write_out_longhorn_custom_overrides_file

if [ -e ${CUSTOM_OVERRIDES_FILE} ]
then
  display_custom_overrides_file
fi

deploy_csi_driver_nfs

write_out_nfs_storageclass_manifest
display_nfs_storageclass_manifest
create_csi_driver_nfs_storageclss

display_storage_classes
