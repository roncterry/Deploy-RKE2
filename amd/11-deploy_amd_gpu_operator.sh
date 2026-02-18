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
  AMDGPU_OPERATOR_VERSION=v1.1.0
  AMDGPU_OPERATOR_DRIVER_ENABLE=false
  AMDGPU_OPERATOR_REPO_URL=https://rocm.github.io/gpu-operator
fi

CUSTOM_OVERRIDES_FILE=amd_gpu_operator_custom_overrides.yaml

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

write_out_amd_gpu_operator_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} ..."
  echo

  echo "
" > ${CUSTOM_OVERRIDES_FILE}
}

install_amd_gpu_operator() {
  if ! [ -z ${AMDGPU_OPERATOR_VERSION} ]
  then
    AMDGPU_OPERATOR_VERSION_OPT="--version=${AMDGPU_OPERATOR_VERSION}"
  else
    AMDGPU_OPERATOR_VERSION_OPT=""
  fi

  echo "COMMAND: helm repo add rocm https://rocm.github.io/gpu-operator"
  helm repo add rocm https://rocm.github.io/gpu-operator
  echo

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm install amd-gpu-operator rocm/gpu-operator-charts --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace --set deviceConfig.spec.driver.enable=${AMDGPU_OPERATOR_DRIVER_ENABLE} ${AMDGPU_OPERATOR_VERSION_OPT}"
  helm install amd-gpu-operator rocm/gpu-operator-charts --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace --set deviceConfig.spec.driver.enable=${AMDGPU_OPERATOR_DRIVER_ENABLE} ${AMDGPU_OPERATOR_VERSION_OPT}
  echo
}

install_amd_gpu_device_plugin() {
  echo "COMMAND: helm repo add amd-gpu-device-plugin https://rocm.github.io/k8s-device-plugin/"
  helm repo add amd-gpu-device-plugin https://rocm.github.io/k8s-device-plugin/
  echo

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm install amd-gpu amd-gpu-device-plugin/amd-gpu --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace" 
  helm install amd-gpu amd-gpu-device-plugin/amd-gpu --namespace ${AMDGPU_OPERATOR_NAMESPACE} --create-namespace 
  echo

}

check_amd_gpu_operator_deployment_status() {
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

label_amd_gpu_nodes() {
  echo
  echo "COMMAND: wget https://raw.githubusercontent.com/ROCm/k8s-device-plugin/refs/heads/master/k8s-ds-amdgpu-labeller.yaml"
  wget https://raw.githubusercontent.com/ROCm/k8s-device-plugin/refs/heads/master/k8s-ds-amdgpu-labeller.yaml

  echo
  echo "kubectl create -f k8s-ds-amdgpu-labeller.yaml"
  kubectl create -f k8s-ds-amdgpu-labeller.yaml

  #echo
  #echo "COMMAND: kubectl create -f https://raw.githubusercontent.com/ROCm/k8s-device-plugin/refs/heads/master/k8s-ds-amdgpu-labeller.yaml"
  #kubectl create -f https://raw.githubusercontent.com/ROCm/k8s-device-plugin/refs/heads/master/k8s-ds-amdgpu-labeller.yaml
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
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  label_only)
    check_for_kubectl
    label_amd_gpu_nodes
    show_amdgpu_node_labels
  ;;
  verify_only)
    check_for_kubectl
    check_amd_gpu_operator_deployment_status
    show_amdgpu_node_labels
  ;;
  *)
    check_for_kubectl
    check_for_helm

    install_amd_gpu_operator
    install_amd_gpu_device_plugin
    check_amd_gpu_operator_deployment_status
    label_amd_gpu_nodes
    show_amdgpu_node_labels

  ;;
esac

