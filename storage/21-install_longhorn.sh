#!/bin/bash

# You can either source in the variables from a common config file or
# set them in this script.

CONFIG_FILE=deploy_storage.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  LH_HELM_REPO_URL=https://charts.longhorn.io
  LH_HELM_CHART=
  LH_VERSION=
  LH_NAMESPACE=longhorn-system
  LH_USER="admin"
  LH_PASSWORD="longhorn"
  LH_URL="longhorn.example.com"
  LH_DEFAULT_REPLICA_COUNT=1
  LH_DEFAULT_CLASS_REPLICA_COUNT=1
  LH_CSI_REPLICA_COUNT=1
  LH_UI_REPLICA_COUNT=1
  LH_RESERVED_DISK_PERCENTAGE=15
  LH_DEFAULT_SC_FS_TYPE=ext4
  LH_ADDITIONAL_SC_LIST=
fi

if [ -z ${LH_URL} ]
then
  LH_URL="$(hostname -f)"
fi

LICENSES_FILE=../authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=longhorn-values.yaml

source /etc/os-release

##############################################################################

case $(whoami) in
  root)
    SUDO_CMD=""
  ;;
  *)
    SUDO_CMD="sudo"
  ;;
esac

###############################################################################
#   Functions
###############################################################################

test_user() {
  if whoami | grep -q root
  then
    echo
    echo "ERROR: You must run this script as a non-root user. Exiting."
    echo
    exit 1
  fi
}

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


install_openiscsi() {
  case ${NAME} in
    SLES)
      if ! zypper se open-iscsi | grep open-iscsi | grep -q ^i
      then
        echo "Installing open-iscsi ..."
        echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses open-iscsi"
        ${SUDO_CMD} zypper install -y --auto-agree-with-licenses open-iscsi
        echo
      fi
    ;;
  esac
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

create_app_collection_secret() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi

  if ! [ -z ${LH_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${LH_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${LH_NAMESPACE}"
      kubectl create namespace ${LH_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${LH_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${LH_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} get secrets"
      kubectl -n ${LH_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${LH_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${LH_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${LH_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} get secrets"
      kubectl -n ${LH_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${LH_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${LH_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  else
    if ! kubectl get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl get secrets"
      kubectl get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl get secrets"
      kubectl get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  fi
}

patch_serviceaccounts() {
  #echo COMMAND: kubectl patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  #kubectl patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  #echo

  echo COMMAND: kubectl -n ${LH_NAMESPACE} patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  kubectl -n ${LH_NAMESPACE} patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  echo
}

write_out_longhorn_custom_overrides_file() {
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
  replicas: ${LH_UI_REPLICAS}  " >> ${CUSTOM_OVERRIDES_FILE}
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

deploy_longhorn() {
  if ! [ -z ${LH_VERSION} ]
  then
    local LHN_VER_ARG="--version ${LH_VERSION}"
  fi

  if [ -z ${LH_HELM_CHART} ]
  then
    if ! helm repo list | grep -q longhorn
    then
      echo "COMMAND: helm repo add longhorn ${LH_HELM_REPO_URL}"
      helm repo add longhorn ${LH_HELM_REPO_URL}
    fi

    echo "COMMAND: helm repo update"
    helm repo update
    echo
 
    echo "COMMAND: helm upgrade --install longhorn --namespace ${LH_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} longhorn/longhorn ${LHN_VER_ARG}"
    helm upgrade --install longhorn --namespace ${LH_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} longhorn/longhorn ${LHN_VER_ARG}
    echo
 
    echo "COMMAND: kubectl -n ${LH_NAMESPACE} rollout status deploy/longhorn-driver-deployer"
    kubectl -n ${LH_NAMESPACE} rollout status deploy/longhorn-driver-deployer
    echo
  else
    log_into_app_collection
    create_app_collection_secret

    echo "COMMAND: helm upgrade --install longhorn ${LH_HELM_CHART} --namespace ${LH_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} -f ${CUSTOM_OVERRIDES_FILE} ${LHN_VER_ARG}"
    helm upgrade --install longhorn ${LH_HELM_CHART} --namespace ${LH_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} -f ${CUSTOM_OVERRIDES_FILE} ${LHN_VER_ARG}
  fi

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

create_longhorn_ingress_secret() {
  echo "${LH_USER}:$(openssl passwd -stdin -apr1 <<< ${LH_PASSWORD})" > longhorn-auth

  echo "Creating secret for Longhorn ingress access ..."
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} create secret generic longhorn-auth --from-file=longhorn-auth"
  kubectl -n ${LH_NAMESPACE} create secret generic longhorn-auth --from-file=longhorn-auth
  echo
}

write_out_longhorn_ingress_manifest() {
  echo "Writing out longhorn-ingress.yaml ..."
  echo
  echo "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: ${LH_NAMESPACE}
  annotations:
    # type of authentication
    nginx.ingress.kubernetes.io/auth-type: basic
    # prevent the controller from redirecting (308) to HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    # name of the secret that contains the user/password definitions
    nginx.ingress.kubernetes.io/auth-secret: longhorn-auth
    # message to display with an appropriate context why the authentication is required
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
    # custom max body size for file uploading like backing image uploading
    nginx.ingress.kubernetes.io/proxy-body-size: 10000m
spec:
  rules:
  - host: "${LH_URL}"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
" > longhorn-ingress.yaml
  echo
  cat longhorn-ingress.yaml
  echo
}

create_longhorn_ingress() {
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} create -f longhorn-ingress.yaml"
  kubectl -n ${LH_NAMESPACE} create -f longhorn-ingress.yaml
  echo

  echo "-----------------------------------------------------------------------------"
  echo "COMMAND: kubectl -n ${LH_NAMESPACE} get ingresses"
  kubectl -n ${LH_NAMESPACE} get ingresses
  echo 
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
    write_out_longhorn_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    install_openiscsi
    check_for_kubectl
    check_for_helm
    display_custom_overrides_file
    deploy_longhorn
    create_additional_storageclasses
    display_storage_classes
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    install_openiscsi
    check_for_kubectl
    check_for_helm
    write_out_longhorn_custom_overrides_file
    display_custom_overrides_file
    deploy_longhorn
    create_additional_storageclasses
    display_storage_classes
  ;;
esac

if echo ${*} | grep -q with_ingress
then
  write_out_longhorn_ingress_manifest
  create_longhorn_ingress_secret
  create_longhorn_ingress
fi
