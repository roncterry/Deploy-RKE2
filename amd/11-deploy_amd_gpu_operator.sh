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
  AMDGPU_OPERATOR_TYPE=operator
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

write_out_amdgpu_device_plugin_custom_overrides_file() {
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
}

check_amdgpu_device_plugin_deployment_status() {
  echo -n "Waiting for namespace to be created "
  until kubectl get namespaces | grep -q ${AMDGPU_OPERATOR_NAMESPACE}
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-device-plugin-daemonset"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-device-plugin-daemonset
  echo

  echo "COMMAND: kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-operator-node-feature-discovery-worker"
  kubectl -n ${AMDGPU_OPERATOR_NAMESPACE} rollout status daemonset/amd-gpu-operator-node-feature-discovery-worker
  echo
}

retrieve_node_labeller_manifest() {
  if ! [ -e ${AMDGPU_NODE_LABELLER_MANIFEST_FILE} ]
  then
    echo
    echo "COMMAND: wget ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
    wget ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
    echo
 
    cat ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
    echo
  else
    echo "(Node labeller manifest already present.)"
    echo
  fi

}

apply_node_labeller_manifest() {
  echo
  echo "kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
  kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
  echo

  #echo
  #echo "COMMAND: kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
  #kubectl create -f ${AMDGPU_NODE_LABELLER_MANIFEST_BASE_URL}/${AMDGPU_NODE_LABELLER_MANIFEST_FILE}

  echo -n "Waiting for the labeller daemonset to be ready ."
  until kubectl -n kube-system get pod | grep amdgpu-labeller-daemonset | grep -q Running
  do
    echo -n "."
    sleep 1
  done
  echo "."

  echo -n "Waiting for the labeller to label nodes ."
  until kubectl get nodes -o yaml | grep -q "amd.com/gpu"
  do
    echo -n "."
    sleep 1
  done
  echo "."
  echo
}

check_for_amdgpu_driver_loaded() {
  for GPU in $(lspci | grep VGA | awk '{ print $1 }')
  do 
    if $(lspci -vs ${GPU}|grep "Kernel driver in use:"|grep -q amdgpu)
    then 
      export AMDGPU_DRIVER_LOADED=true
    else 
      export AMDGPU_DRIVER_LOADED=false
    fi
  done
}

label_amdgpu_nodes() {
  for NODE in $(kubectl get nodes | grep -v ^NAME | awk '{ print $1 }')
  do
    echo "---------------------"
    echo "Node: ${NODE}"
    echo "---------------------"

    ## FIXME: This needs a better way to discover on all nodes both local and remote.
    #if kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | grep -q "amd.com/gpu"
    #if kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "amd.com/gpu"
    if [ ${AMDGPU_DRIVER_LOADED} == true ]
    then
      echo GPU_NODE=true
      echo
 
      if ! kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | grep -q "accelerator"
      #if ! kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "accelerator"
      then
        echo "COMMAND: kubectl label node ${NODE} accelerator=amd-gpu"
        kubectl label node ${NODE} accelerator=amd-gpu
        echo
      fi
 
    else
      echo GPU_NODE=false
      echo
      echo "Note: If you think this is incorrect it may be because the metadata labels"
      echo "      may not have been updated yet."
      echo "      Wait about 10-15 seconds and run this script again with the 'label_only'"
      echo "      argument to attempt the labeling of the GPU nodes again."
      echo
    fi
  done
}

show_amdgpu_node_labels() {
  echo
  echo "COMMAND: kubectl get nodes -o yaml | grep -E 'amd.com|accelerator'"
  kubectl get nodes -o yaml | grep -E 'amd.com|accelerator'
  echo
}

uninstall_amdgpu_device_plugin() {
  echo
  echo "COMMAND: helm -n ${AMDGPU_OPERATOR_NAMESPACE} uninstall amd-gpu"
  helm -n ${AMDGPU_OPERATOR_NAMESPACE} uninstall amd-gpu
  echo
}

uninstall_amdgpu_operator() {
  echo
  echo "COMMAND: helm -n ${AMDGPU_OPERATOR_NAMESPACE} uninstall amd-gpu-operator"
  helm -n ${AMDGPU_OPERATOR_NAMESPACE} uninstall amd-gpu-operator
  echo
}

uninstall_node_labeller() {
  if ! [ -e ${AMDGPU_NODE_LABELLER_MANIFEST_FILE} ]
  then
    retrieve_node_labeller_manifest
  fi

  echo
  echo "COMMAND: kubectl delete -f ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}"
  kubectl delete -f ${AMDGPU_NODE_LABELLER_MANIFEST_FILE}
  echo
}

remove_labels_from_nodes() {
  echo
  for NODE in $(kubectl get nodes | grep -v ^NAME | awk '{ print $1 }')
  do
    echo "---------------------"
    echo "Node: ${NODE}"
    echo "---------------------"

    for LABEL in $(kubectl get nodes -o yaml | grep amd.com |cut -d : -f 1) 
    do 
      echo "COMMAND: kubectl label node ${NODE} ${LABEL}-"
      kubectl label node ${NODE} ${LABEL}- 
    done
    echo

    for ANNOTATION in $(kubectl get nodes -o yaml | grep amd.com |cut -d : -f 1) 
    do 
      echo "COMMAND: kubectl annotate node ${NODE} ${ANNOTATION}-"
      kubectl annotate node ${NODE} ${ANNOTATION}- 
    done
    echo

    kubectl label node ${NODE} accelerator-

  done
  echo
}

usage() {
  echo
  echo "USAGE: ${0} [label_only|verify_only|uninstall]"
  echo
  echo "Options: "
  echo "    label_only           (only label the GPU nodes)"
  echo "    verify_only          (only display verification of the GPU nodes)"
  echo "    uninstall            (uninstall the operator)"
  echo
  echo "If no option is supplied the installation is performent using "
  echo "'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} label_only"
  echo "         ${0} verify_only"
  echo "         ${0} uninstall"
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

    #case ${AMDGPU_OPERATOR_TYPE} in
    #  operator)
    #    write_out_amdgpu_operator_custom_overrides_file
    #  ;;
    #  device-plugin)
    #    write_out_amdgpu_device_plugin_custom_overrides_file
    #  ;;
    #esac

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

    case ${AMDGPU_OPERATOR_TYPE} in
      operator)
        check_amdgpu_operator_deployment_status
      ;;
      device-plugin)
        check_amdgpu_device_plugin_deployment_status
      ;;
    esac

    show_amdgpu_node_labels
  ;;
  uninstall)
    case ${AMDGPU_OPERATOR_TYPE} in
      operator)
        uninstall_amdgpu_operator
      ;;
      device-plugin)
        uninstall_amdgpu_device_plugin
      ;;
    esac

    uninstall_node_labeller
    remove_labels_from_nodes
  ;;
  *)
    check_for_kubectl
    check_for_helm

    case ${AMDGPU_OPERATOR_TYPE} in
      operator)
        #write_out_amdgpu_operator_custom_overrides_file
        install_amdgpu_operator
        check_amdgpu_operator_deployment_status
      ;;
      device-plugin)
        #write_out_amdgpu_device_plugin_custom_overrides_file
        install_amdgpu_device_plugin
        check_amdgpu_device_plugin_deployment_status
      ;;
    esac

    retrieve_node_labeller_manifest
    label_amdgpu_nodes
    show_amdgpu_node_labels
  ;;
esac

