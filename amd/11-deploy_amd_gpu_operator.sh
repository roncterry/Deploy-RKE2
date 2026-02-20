#!/bin/bash

##############################################################################
# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_amd_gpu_operator.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  AMDGPU_OPERATOR_NAMESPACE=kube-amd-gpu
  AMDGPU_OPERATOR_REPO_URL=https://rocm.github.io/gpu-operator
  AMDGPU_OPERATOR_VERSION=
  AMDGPU_OPERATOR_DRIVER_ENABLE=false
  AMDGPU_DEVICE_PLUGIN_REPO_URL=https://rocm.github.io/k8s-device-plugin
  AMDGPU_DEVICE_PLUGIN_VERSION=
  AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL=https://raw.githubusercontent.com/ROCm/k8s-device-plugin/refs/heads/master
fi

AMDGPU_OPERATOR_CUSTOM_OVERRIDES_FILE=amdgpu_operator_custom_overrides.yaml
AMDGPU_DEVICE_PLUGIN_CUSTOM_OVERRIDES_FILE=amdgpu_device_plugin_custom_overrides.yaml

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

write_out_amdgpu_operator_custom_overrides_file() {
  echo "Writing out ${AMDGPU_OPERATOR_CUSTOM_OVERRIDES_FILE} ..."
  echo

  echo "
" > ${AMDGPU_OPERATOR_CUSTOM_OVERRIDES_FILE}
}

write_out_amdgpu_devide_plugin_custom_overrides_file() {
  echo "Writing out ${AMDGPU_DEVICE_PLUGIN_CUSTOM_OVERRIDES_FILE} ..."
  echo

  echo "
" > ${AMDGPU_OPERATOR_CUSTOM_OVERRIDES_FILE}
}

install_amdgpu_operator() {
  if ! [ -z ${AMDGPU_OPERATOR_VERSION} ]
  then
    AMDGPU_OPERATOR_VERSION_OPT="--version=${AMDGPU_OPERATOR_VERSION}"
  else
    AMDGPU_OPERATOR_VERSION_OPT=""
  fi

  echo "COMMAND: helm repo add rocm ${AMDGPU_OPERATOR_REPO_URL}"
  helm repo add rocm ${AMDGPU_OPERATOR_REPO_URL}
  echo

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm upgrade --install amd-gpu-operator rocm/gpu-operator-charts --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace --set deviceConfig.spec.driver.enable=${AMDGPU_OPERATOR_DRIVER_ENABLE} ${AMDGPU_OPERATOR_VERSION_OPT}"
  helm upgrade --install amd-gpu-operator rocm/gpu-operator-charts --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace --set deviceConfig.spec.driver.enable=${AMDGPU_OPERATOR_DRIVER_ENABLE} ${AMDGPU_OPERATOR_VERSION_OPT}
  echo
}

install_amdgpu_device_plugin() {
  if ! [ -z ${AMDGPU_DEVICE_PLUGIN_VERSION} ]
  then
    AMDGPU_DEVICE_PLUGIN_VERSION_OPT="--version=${AMDGPU_DEVICE_PLUGIN_VERSION}"
  else
    AMDGPU_DEVICE_PLUGIN_VERSION_OPT=""
  fi

  echo "COMMAND: helm repo add amd-gpu-device-plugin ${AMDGPU_DEVICE_PLUGIN_REPO_URL}"
  helm repo add amd-gpu-device-plugin ${AMDGPU_DEVICE_PLUGIN_REPO_URL}
  echo

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm upgrade --install amd-gpu amd-gpu-device-plugin/amd-gpu --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace ${AMDGPU_DEVICE_PLUGIN_VERSION_OPT}" 
  helm upgrade --install amd-gpu amd-gpu-device-plugin/amd-gpu --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace  ${AMDGPU_DEVICE_PLUGIN_VERSION_OPT}
  echo
}

check_amdgpu_operator_deployment_status() {
  echo -n "Waiting for namespace to be created "
  until kubectl get namespaces | grep -q ${AMDGPU_OPERATOR_NAMESPACE}
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

#  echo -n "Waiting for amd-gpu-operator-gpu-operator-charts-controller-manager deployment to be started "
#  until kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} get deployment | grep -q amd-gpu-operator-gpu-operator-charts-controller-manager
#  do
#    echo -n "."
#    sleep 2
#  done
#  echo "."
#  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-gpu-operator-charts-controller-manager"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-gpu-operator-charts-controller-manager
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-kmm-controller"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-kmm-controller
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-kmm-webhook-server"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-kmm-webhook-server
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-node-feature-discovery-gc"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-node-feature-discovery-gc
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-node-feature-discovery-master"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status deploy/amd-gpu-operator-node-feature-discovery-master
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-device-plugin-daemonset"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-device-plugin-daemonset
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-operator-node-feature-discovery-worker"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-operator-node-feature-discovery-worker
  echo

#  sleep 5
}

retrieve_node_labeller_manifest() {
  echo
  echo "COMMAND: wget ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
  wget ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
  echo

  cat ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
  echo
}

label_amdgpu_nodes() {
  echo
  echo "kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
  kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}

  #echo
  #echo "COMMAND: kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
  #kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
}

show_amdgpu_node_labels() {
  echo
  echo "COMMAND: kubectl get nodes -o yaml | grep amd.com"
  kubectl get nodes -o yaml | grep amd.com
  echo
}

usage() {
  echo
  echo "USAGE: ${0} [label_only|verify_only]"
  echo
  echo "Options: "
  echo "    label_only           (only label the GPU nodes)"
  echo "    verify_only          (only display verification of the GPU nodes)"
  echo
  echo "If no option is supplied the installation is performent using "
  echo "'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} label_only"
  echo "         ${0} verify_only"
  echo
}

##############################################################################

case ${1} in
  verify_only)
    check_for_kubectl

    show_amdgpu_node_labels
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  config_only)
    check_for_kubectl

    #write_out_amdgpu_operator_custom_overrides_file
    #write_out_amdgpu_devide_plugin_custom_overrides_file
    retrieve_node_labeller_manifest
  ;;
  label_only)
    check_for_kubectl

    retrieve_node_labeller_manifest
    label_amdgpu_nodes
    show_amdgpu_node_labels
  ;;
  verify_only)
    check_for_kubectl

    check_amdgpu_operator_deployment_status
    show_amdgpu_node_labels
  ;;
  *)
    check_for_kubectl
    check_for_helm

    #write_out_amdgpu_operator_custom_overrides_file
    install_amdgpu_operator
    #write_out_amdgpu_devide_plugin_custom_overrides_file
    install_amdgpu_device_plugin
    check_amdgpu_operator_deployment_status
    retrieve_node_labeller_manifest
    label_amdgpu_nodes
    show_amdgpu_node_labels
  ;;
esac

