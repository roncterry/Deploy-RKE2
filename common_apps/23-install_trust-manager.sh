#!/bin/bash

##############################################################################
# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_common_apps.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  IMAGE_PULL_SECRET_NAME=application-collection

  TRUSTMANAGER_HELM_REPO="https://charts.jetstack.io"
  TRUSTMANAGER_HELM_CHART="oci://dp.apps.rancher.io/charts/trust-manager"
  TRUSTMANAGER_VERSION=
  TRUSTMANAGER_NAMESPACE=cert-manager
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

CUSTOM_OVERRIDES_FILE=tm_custom_overrides.yaml

##############################################################################

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

  if ! [ -z ${TRUSTMANAGER_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${TRUSTMANAGER_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${TRUSTMANAGER_NAMESPACE}"
      kubectl create namespace ${TRUSTMANAGER_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${TRUSTMANAGER_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} get secrets"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} get secrets"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${TRUSTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
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

create_trustmanager_base_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  if ! [ -z ${TRUSTMANAGER_HELM_CHART} ]
  then
    if ! [ -z ${IMAGE_PULL_SECRET_NAME} ]
    then
      echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}" > ${CUSTOM_OVERRIDES_FILE}
    fi
  else
    touch ${CUSTOM_OVERRIDES_FILE}
  fi

  case ${TRUSTMANAGER_SECRETTARGETS_ENABLED} in
    true)
      echo "secretTargets:
  enabled: ${TRUSTMANAGER_SECRETTARGETS_ENABLED}
  authorizedSecretsAll: ${TRUSTMANAGER_AUTHORIZEDSECRETSALL}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  echo "app:
  trust:
    namespace: ${TRUSTMANAGER_APP_TRUST_NAMESPACE}" >> ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_trustmanager() {
  if ! [ -z ${TRUSTMANAGER_VERSION} ]
  then
    local TM_VER_ARG="--version ${TRUSTMANAGER_VERSION}"
  fi

  echo "Installing Cert-Manager ..."
  echo "------------------------------------------------------------"
  if [ -z ${TRUSTMANAGER_HELM_CHART} ]
  then
    echo "COMMAND: 
    helm repo add cert-manager ${TRUSTMANAGER_HELM_REPO}
    helm repo update"
 
    helm repo add cert-manager ${TRUSTMANAGER_HELM_REPO}
    helm repo update
 
    echo
    create_trustmanager_base_custom_overrides_file
    display_custom_overrides_file

    if ! [ -z ${TRUSTMANAGER_APP_TRUST_NAMESPACE} ]
    then
      echo "COMMAND: kubectl create namesapace ${TRUSTMANAGER_APP_TRUST_NAMESPACE}"
      kubectl create namespace ${TRUSTMANAGER_APP_TRUST_NAMESPACE}
      echo
    fi

    echo
    echo "COMMAND: helm upgrade --install trust-manager cert-manager/trust-manager --namespace ${TRUSTMANAGER_NAMESPACE} --create-namespace --set crds.enabled=true -f ${CUSTOM_OVERRIDES_FILE} ${TM_VER_ARG}"
    helm upgrade --install trust-manager cert-manager/trust-manager --namespace ${TRUSTMANAGER_NAMESPACE} --create-namespace --set crds.enabled=true -f ${CUSTOM_OVERRIDES_FILE} ${TM_VER_ARG}
  else
    log_into_app_collection
    create_app_collection_secret
    #patch_serviceaccounts
    create_trustmanager_base_custom_overrides_file
    display_custom_overrides_file

    echo "COMMAND: helm upgrade --install trust-manager ${TRUSTMANAGER_HELM_CHART} --namespace ${TRUSTMANAGER_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} --set crds.enabled=true -f ${CUSTOM_OVERRIDES_FILE} ${TM_VER_ARG}"
    helm upgrade --install trust-manager ${TRUSTMANAGER_HELM_CHART} --namespace ${TRUSTMANAGER_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} --set crds.enabled=true -f ${CUSTOM_OVERRIDES_FILE} ${TM_VER_ARG}
  fi

  #echo
  #echo "COMMAND: helm upgrade --install trust-manager oci://dp.apps.rancher.io/charts/trust-manager --namespace ${TRUSTMANAGER_NAMESPACE} -f ${CUSTOM_OVERRIDES_FILE} --create-namespace --set crds.enabled=true -f ${CUSTOM_OVERRIDES_FILE} ${TM_VER_ARG}"
  #helm upgrade --install trust-manager oci://dp.apps.rancher.io/charts/trust-manager --namespace ${TRUSTMANAGER_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} --set crds.enabled=true -f ${CUSTOM_OVERRIDES_FILE} ${TM_VER_ARG}

  echo
  echo "COMMAND: kubectl -n ${TRUSTMANAGER_NAMESPACE} rollout status deploy/trust-manager"
  kubectl -n ${TRUSTMANAGER_NAMESPACE} rollout status deploy/trust-manager

  echo
}

##############################################################################

check_for_kubectl
check_for_helm
if helm list -n ${TRUSTMANAGER_NAMESPACE} | grep -q trust-manager
then
  echo
  echo "Trust-Manager is already installed. Exiting."
  echo
else
  install_trustmanager
fi

