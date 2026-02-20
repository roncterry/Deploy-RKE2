#!/bin/bash

##############################################################################

# You can either source in the variables from a common config file or
# set the them in this script.

CONFICONFIG_FILE=deploy_storage.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  IMAGE_PULL_SECRET_NAME=application-collection
  STORAGE_CLASS_NAME=longhorn
  LH_HELM_CHART=oci://dp.apps.rancher.io/charts/suse-storage
  LH_VERSION=
  LH_NAMESPACE=suse-storage
  LH_DEFAULT_REPLICA_COUNT=1
  LH_DEFAULT_CLASS_REPLICA_COUNT=1
  LH_CSI_REPLICA_COUNT=1
  LH_UI_REPLICA_COUNT=1
  LH_RESERVED_DISK_PERCENTAGE=15
  LH_DEFAULT_SC_FS_TYPE=ext4
  LH_DEFAULT_DATAENGINE=v1
  LH_V1_DATAENGINE_ENABLED=true
  LH_V2_DATAENGINE_ENABLED=false
  LH_ADDITIONAL_SC_LIST=
fi

LICENSES_FILE=../authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=suse_storage_custom_overrides.yaml

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

##############################################################################

check_for_image_pull_secret() {
  if ! kubectl -n ${LH_NAMESPACE} get secrets | grep -q ${IMAGE_PULL_SECRET_NAME}
  then
    echo
    echo "ERROR: The image pull secret ${IMAGE_PULL_SECRET} is not in the namespace."
    echo "       Please create the secret before installing this application."
    echo 
    echo "       Exiting."
    echo

    exit
  fi
}

log_into_app_collection() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi


  echo "Logging into the Application Collection ..."
  echo "COMMAND: helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}"
  helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}
  echo
}

write_out_suse_storage_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo

  if ! [ -z ${LH_HELM_CHART} ]
  then
    echo "global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}" > ${CUSTOM_OVERRIDES_FILE}
  else
    echo "" > ${CUSTOM_OVERRIDES_FILE}
  fi

  echo "csi:
  attacherReplicaCount: ${LH_CSI_REPLICA_COUNT}
  provisionerReplicaCount: ${LH_CSI_REPLICA_COUNT}
  resizerReplicaCount: ${LH_CSI_REPLICA_COUNT}
  snapshotterReplicaCount: ${LH_CSI_REPLICA_COUNT}" >> ${CUSTOM_OVERRIDES_FILE}

  echo "defaultSettings:
  defaultReplicaCount: ${LH_DEFAULT_REPLICA_COUNT}
  storageReservedPercentageForDefaultDisk: ${LH_RESERVED_DISK_PERCENTAGE}" >> ${CUSTOM_OVERRIDES_FILE}
  case ${LH_V1_DATAENGINE_ENABLED} in
    true)
      echo "  v1DataEngine: true" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac
  case ${LH_V2_DATAENGINE_ENABLED} in
    true)
      echo "  v2DataEngine: true" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  if ! [ -z ${LH_UI_REPLICA_COUNT} ]
  then
    echo "longhornUI:
  replicas: ${LH_UI_REPLICA_COUNT}  " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  echo "persistence:
  dataEngine: ${LH_DATA_ENGINE}
  defaultClassReplicaCount: ${LH_DEFAULT_CLASS_REPLICA_COUNT}
  defaultFsType: ${LH_DEFAULT_SC_FS_TYPE}" >> ${CUSTOM_OVERRIDES_FILE}

  echo
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

deploy_suse_storage() {
  if ! [ -z ${LH_VERSION} ]
  then
    local LHN_VER_ARG="--version ${LH_VERSION}"
  fi

  check_for_image_pull_secret
  log_into_app_collection

  echo "COMMAND: helm upgrade --install suse-storage ${LH_HELM_CHART} --namespace ${LH_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${LHN_VER_ARG}"
  helm upgrade --install suse-storage ${LH_HELM_CHART} --namespace ${LH_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${LHN_VER_ARG}
  echo
}

check_suse_storage_deployment_status() {
  until kubectl -n ${LH_NAMESPACE} rollout status deploy/longhorn-ui > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} rollout status deploy/longhorn-ui"
  kubectl -n ${LH_NAMESPACE} rollout status deploy/longhorn-ui
  echo

  until kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-attacher > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-attacher"
  kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-attacher
  echo

  until kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-provisioner > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-provisioner"
  kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-provisioner
  echo

  until kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-resizer > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-resizer"
  kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-resizer
  echo

  until kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-snapshotter > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-snapshotter"
  kubectl -n ${LH_NAMESPACE} rollout status deploy/csi-snapshotter
  echo
}

create_additional_storageclasses() {
  local SC_NAME_PREFIX=longhorn

  if ! [ -z ${LH_ADDITIONAL_SC_LIST} ]
  then
    for SC in ${LH_ADDITIONAL_SC_LIST}
    do
      local SC_NAME=$(echo ${SC} | cut -d , -f 1)
      local FS_TYPE=$(echo ${SC} | cut -d , -f 2)
      local NUM_REPLICAS=$(echo ${SC} | cut -d , -f 3)

      if [ -z ${NUM_REPLICAS} ]
      then
        NUM_REPLICAS=3
      fi

      echo "Writing out StoragecCass manifest: ${SC_NAME}"
      echo
      echo "apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${SC_NAME}
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: \"${NUM_REPLICAS}\"
  staleReplicaTimeout: \"30\"
  fromBackup: 
  fsType: \"${FS_TYPE}\"
  dataLocality: \"disabled\"
  unmapMarkSnapChainRemoved: \"ignored\" " > ${SC_NAME}.yaml

      echo
      cat ${SC_NAME}.yaml
      echo

      echo "Creating storage class: ${SC_NAME}"
      echo
      echo "COMMAND: kubectl apply -f ${SC_NAME}.yaml"
      kubectl apply -f ${SC_NAME}.yaml
      echo
    done
  fi
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

usage() {
  echo
  echo "USAGE: ${0} [custom_overrides_only|install_only]"
  echo
  echo "Options: "
  echo "    custom_overrides_only  (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "    install_only           (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo
  echo "If no option is supplied the ${CUSTOM_OVERRIDES_FILE} file is created and"
  echo "is used to perform an installation using 'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo
}

###############################################################################

case ${1} in
  custom_overrides_only)
    write_out_suse_storage_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    display_custom_overrides_file
    deploy_suse_storage
    check_suse_storage_deployment_status
    create_additional_storageclasses
    display_storage_classes
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    write_out_suse_storage_custom_overrides_file
    display_custom_overrides_file
    deploy_suse_storage
    check_suse_storage_deployment_status
    create_additional_storageclasses
    display_storage_classes
  ;;
esac

