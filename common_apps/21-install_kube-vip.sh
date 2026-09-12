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

  KUBEVIP_HELM_REPO="https://kube-vip.github.io/helm-charts"
  KUBEVIP_HELM_CHART="oci://dp.apps.rancher.io/charts/kube-vip"
  KUBEVIP_VERSION=
  KUBEVIP_NAMESPACE=kube-vip
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

CUSTOM_OVERRIDES_FILE=kubevip_custom_overrides.yaml

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

  if ! [ -z ${KUBEVIP_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${KUBEVIP_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${KUBEVIP_NAMESPACE}"
      kubectl create namespace ${KUBEVIP_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${KUBEVIP_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${KUBEVIP_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} get secrets"
      kubectl -n ${KUBEVIP_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${KUBEVIP_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${KUBEVIP_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${KUBEVIP_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} get secrets"
      kubectl -n ${KUBEVIP_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${KUBEVIP_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
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

  echo COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  kubectl -n ${KUBEVIP_NAMESPACE} patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  echo
}

create_kubevip_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME} 
config:
  address: \"${KUBEVIP_ADDRESS}\" 
env:
  vip_interface: \"${KUBEVIP_INTERFACE}\"
  cp_enable: \"${KUBEVIP_CP_ENABLE}\"
  vip_leaderelection: \"${KUBEVIP_VIP_LEADERELECTION}\"
nodeSelector:
  node-role.kubernetes.io/control-plane: \"${KUBEVIP_CP_ENABLE}\"" > ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_kubevip() {
  if ! [ -z ${KUBEVIP_VERSION} ]
  then
    local KUBEVIP_VER_ARG="--version ${KUBEVIP_VERSION}"
  fi

  echo "Installing Kube_VIP ..."
  echo "------------------------------------------------------------"
  if [ -z ${KUBEVIP_HELM_CHART} ]
  then
    create_kubevip_custom_overrides_file
    display_custom_overrides_file

    echo "COMMAND: 
    helm repo add kube-vip ${KUBEVIP_HELM_REPO}
    helm repo update"
 
    helm repo add kube-vip ${KUBEVIP_HELM_REPO}
    helm repo update
 
    echo
    echo "COMMAND: helm upgrade --install kube-vip kube-vip/kube-vip --namespace ${KUBEVIP_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${KUBEVIP_VER_ARG}"
    helm upgrade --install kube-vip kube-vip/kube-vip --namespace ${KUBEVIP_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${KUBEVIP_VER_ARG}
  else
    log_into_app_collection
    create_app_collection_secret
    #patch_serviceaccounts
    create_kubevip_custom_overrides_file
    display_custom_overrides_file

    echo "COMMAND: helm upgrade --install kube-vip ${KUBEVIP_HELM_CHART} --namespace ${KUBEVIP_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} -f ${CUSTOM_OVERRIDES_FILE} ${KUBEVIP_VER_ARG}"
    helm upgrade --install kube-vip ${KUBEVIP_HELM_CHART} --namespace ${KUBEVIP_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} -f ${CUSTOM_OVERRIDES_FILE} ${KUBEVIP_VER_ARG}
  fi

  echo
  echo "COMMAND: kubectl -n ${KUBEVIP_NAMESPACE} rollout status daemonset/kube-vip"
  kubectl -n ${KUBEVIP_NAMESPACE} rollout status daemonset/kube-vip

  echo
}

##############################################################################

check_for_kubectl
check_for_helm
if helm list -n ${KUBEVIP_NAMESPACE} | grep -q kube-vip
then
  echo
  echo "Kube-VIP is already installed. Exiting."
  echo
else
  install_kubevip
fi

