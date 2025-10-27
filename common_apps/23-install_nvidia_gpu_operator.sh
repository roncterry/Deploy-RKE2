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
  NVIDIA_POD_WAIT_COUNT_MAX=30
  NVIDIA_GPU_OPERATOR_REPO_URL=https://helm.ngc.nvidia.com/nvidia
  NVIDIA_POD_RUNNING_CHECK_COUNT_MAX=30
  NVIDIA_POD_RESET_COUNT_MAX=2
fi


MANIFEST_FILE=nvidia-gpu-operator.yaml

CUSTOM_OVERRIDES_FILE=nvidia_gpu_operator_custom_overrides.yaml


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

write_out_nvidia_gpu_operator_helm_operator_manifest_file() {
  echo "Writing out ${MANIFEST_FILE} (helm operator manifest) ..."
  echo

  echo "
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: ${NVIDIA_GPU_OPERATOR_REPO_URL}
  chart: gpu-operator
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    driver:
      enabled: false
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
      - name: CONTAINERD_CONFIG
        value: /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl
      - name: CONTAINERD_RUNTIME_CLASS
        value: nvidia
      - name: CONTAINERD_SET_AS_DEFAULT
        value: \"true\"
" > ${MANIFEST_FILE}
}

display_nvidia_operator_helm_operator_manifest_file() {
  echo
  cat ${MANIFEST_FILE}
  echo
}

deploy_nvidia_gpu_operator_via_the_helm_operator() {
  echo "COMMAND: kubectl apply -f ${MANIFEST_FILE}"
  kubectl apply -f ${MANIFEST_FILE}
  echo
}

write_out_nvidia_gpu_operator_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} ..."
  echo

  echo "
driver:
  enabled: false
toolkit:
  env:
  - name: CONTAINERD_SOCKET
    value: /run/k3s/containerd/containerd.sock
  - name: CONTAINERD_CONFIG
    value: /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl
  - name: CONTAINERD_RUNTIME_CLASS
    value: nvidia
  - name: CONTAINERD_SET_AS_DEFAULT
    value: \"true\"
" > ${CUSTOM_OVERRIDES_FILE}
}

display_nvidia_gpu_operator_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

deploy_nvidia_gpu_operator() {
  case ${NVIDIA_OPERATOR_VALIDATOR_ENABLED} in
    False|false|F|FALSE|N|NO|n|no)
      echo "COMMAND: kubectl label node ${HOSTNAME} nvidia.com/gpu.deploy.operator-validator=false --overwrite"
      kubectl label node ${HOSTNAME} nvidia.com/gpu.deploy.operator-validator=false --overwrite
      echo
    ;;
    True|true|T|TRUE|Y|YES|y|yes)
      echo "COMMAND: kubectl label node ${HOSTNAME} nvidia.com/gpu.deploy.operator-validator=true --overwrite"
      kubectl label node ${HOSTNAME} nvidia.com/gpu.deploy.operator-validator=true --overwrite
      echo
    ;;
  esac

  if ! grep -q "/usr/local/nvidia/toolkit" /etc/default/rke2-agent
  then
    echo 'COMMAND: echo PATH=${PATH}:/usr/local/nvidia/toolkit >> /etc/default/rke2-agent'
    echo PATH=${PATH}:/usr/local/nvidia/toolkit >> /etc/default/rke2-agent
    echo
  fi

  if ! grep -q "/usr/local/nvidia/toolkit" /etc/default/rke2-server
  then
    echo 'COMMAND: echo PATH=${PATH}:/usr/local/nvidia/toolkit >> /etc/default/rke2-server'
    echo PATH=${PATH}:/usr/local/nvidia/toolkit >> /etc/default/rke2-server
    echo
  fi

  echo "COMMAND: helm repo add nvidia ${NVIDIA_GPU_OPERATOR_REPO_URL}"
  helm repo add nvidia ${NVIDIA_GPU_OPERATOR_REPO_URL}
  echo

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm install gpu-operator -n gpu-operator --create-namespace  -f ${CUSTOM_OVERRIDES_FILE} nvidia/gpu-operator"
  helm install gpu-operator -n gpu-operator --create-namespace -f ${CUSTOM_OVERRIDES_FILE} nvidia/gpu-operator
  echo
}

check_nvidia_gpu_operator_deployment_status() {
  echo -n "Waiting for namespace to be created "
  until kubectl get namespaces | grep -q gpu-operator
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  echo -n "Waiting for gpu-operator deployment to be started "
  until kubectl -n gpu-operator get deployment | grep -q gpu-operator
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  echo "COMMAND: kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-gc"
  kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-gc
  echo

  echo "COMMAND: kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-master"
  kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-master
  echo

  echo "COMMAND: kubectl -n gpu-operator rollout status deploy/gpu-operator"
  kubectl -n gpu-operator rollout status deploy/gpu-operator
  echo

  sleep 5

  #---------------------------------------------------------------------------
  local NVIDIA_GPU_FEATURE_DISCOVERY_WAIT_COUNT=0
  local NVIDIA_GPU_FEATURE_DISCOVERY_CHECK_COUNT=0
  local NVIDIA_GPU_FEATURE_DISCOVERY_POD_RESET_COUNT=0

  echo "Waiting for the gpu-feature-discovery pod to start ... "
  until kubectl -n gpu-operator get pods | grep -q gpu-feature-discovery
  do
    if [ "${NVIDIA_GPU_FEATURE_DISCOVERY_WAIT_COUNT}" -ge "${NVIDIA_POD_WAIT_COUNT_MAX}" ]
    then
      echo "(WARNING: Exceeded wait time for gpu-feature-discovery pod to start. Moving on ...)"
      NVIDIA_GPU_FEATURE_DISCOVERY_CHECK_COUNT=${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}
      NVIDIA_GPU_FEATURE_DISCOVERY_POD_RESET_COUNT=${NVIDIA_POD_RESET_COUNT_MAX}
      break
    else
      ((NVIDIA_GPU_FEATURE_DISCOVERY_WAIT_COUNT++))
      sleep 2
    fi
  done

  echo -n "Waiting for the gpu-feature-discovery pod to become ready "
  until kubectl -n gpu-operator get pods | grep gpu-feature-discovery | grep -q "Running"
  do
    while kubectl -n gpu-operator get pods | grep -q "The connection to the server 127.0.0.1:6443 was refused"
    do
      sleep 5
    done

    if ! kubectl -n gpu-operator get pods | grep -q gpu-feature-discovery
    then
      echo "."
      echo "(WARNING: gpu-feature-discovery pod not found. Continuing ...)"
      break
    fi

    if [ "${NVIDIA_GPU_FEATURE_DISCOVERY_CHECK_COUNT}" -ge "${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}" ]
    then
      if [ "${NVIDIA_GPU_FEATURE_DISCOVERY_POD_RESET_COUNT}" -ge "${NVIDIA_POD_RESET_COUNT_MAX}" ]
      then
        echo "."
        echo "(WARNING: gpu-feature-discovery pod reset to many times. Moving on ...)"
        break
      else
        echo "."
        echo "(gpu-feature-discovery pod not running. Restarting ...)"
        echo "COMMAND: kubectl -n gpu-operator delete pods -l app=gpu-feature-discovery"
        kubectl -n gpu-operator delete pods -l app=gpu-feature-discovery
        NVIDIA_GPU_FEATURE_DISCOVERY_CHECK_COUNT=0
        ((NVIDIA_GPU_FEATURE_DISCOVERY_POD_RESET_COUNT++))
      fi
    fi

    ((NVIDIA_GPU_FEATURE_DISCOVERY_CHECK_COUNT++))
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  #---------------------------------------------------------------------------
  local NVIDIA_DCGM_EXPORTER_WAIT_COUNT=0
  local NVIDIA_DCGM_EXPORTER_CHECK_COUNT=0
  local NVIDIA_DCGM_EXPORTER_POD_RESET_COUNT=0

  echo "Waiting for the nvidia-dcgm-exporter pod to start ... "
  until kubectl -n gpu-operator get pods | grep -q nvidia-dcgm-exporter
  do
    if [ "${NVIDIA_DCGM_EXPORTER_WAIT_COUNT}" -ge "${NVIDIA_POD_WAIT_COUNT_MAX}" ]
    then
      echo "(WARNING: Exceeded wait time for nvidia-dcgm-exporter pod to start. Moving on ...)"
      NVIDIA_DCGM_EXPORTER_CHECK_COUNT=${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}
      NVIDIA_DCGM_EXPORTER_POD_RESET_COUNT=${NVIDIA_POD_RESET_COUNT_MAX}
      break
    else
      ((NVIDIA_DCGM_EXPORTER_WAIT_COUNT++))
      sleep 2
    fi
  done

  echo -n "Waiting for the nvidia-dcgm-exporter pod to become ready "
  until kubectl -n gpu-operator get pods | grep nvidia-dcgm-exporter | grep -q "Running"
  do
    while kubectl -n gpu-operator get pods | grep -q "The connection to the server 127.0.0.1:6443 was refused"
    do
      sleep 5
    done

    if ! kubectl -n gpu-operator get pods | grep -q nvidia-dcgm-exporter
    then
      echo "."
      echo "(WARNING: nvidia-dcgm-exporter pod not found. Continuing ...)"
      break
    fi

    if [ "${NVIDIA_DCGM_EXPORTER_CHECK_COUNT}" -ge "${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}" ]
    then
      if [ "${NVIDIA_DCGM_EXPORTER_POD_RESET_COUNT}" -ge "${NVIDIA_POD_RESET_COUNT_MAX}" ]
      then
        echo "."
        echo "(WARNING: nvidia-dcgm-exporter pod reset to many times. Moving on ...)"
        break
      else
        echo "."
        echo "(nvidia-dcgm-exporter pod not running. Restarting ...)"
        echo "COMMAND: kubectl -n gpu-operator delete pods -l app=nvidia-dcgm-exporter"
        kubectl -n gpu-operator delete pods -l app=nvidia-dcgm-exporter
        NVIDIA_DCGM_EXPORTER_CHECK_COUNT=0
        ((NVIDIA_DCGM_EXPORTER_POD_RESET_COUNT++))
      fi
    fi

    ((NVIDIA_DCGM_EXPORTER_CHECK_COUNT++))
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  #---------------------------------------------------------------------------
  local NVIDIA_DEVICE_PLUGIN_DAEMONSET_WAIT_COUNT=0
  local NVIDIA_DEVICE_PLUGIN_DAEMONSET_CHECK_COUNT=0
  local NVIDIA_DEVICE_PLUGIN_DAEMONSET_POD_RESET_COUNT=0

  echo "Waiting for the nvidia-device-plugin-daemonset pod to start ... "
  until kubectl -n gpu-operator get pods | grep -q nvidia-device-plugin-daemonset
  do
    if [ "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_WAIT_COUNT}" -ge "${NVIDIA_POD_WAIT_COUNT_MAX}" ]
    then
      echo "(WARNING: Exceeded wait time for nvidia-device-plugin-daemonset pod to start. Moving on ...)"
      NVIDIA_DEVICE_PLUGIN_DAEMONSET_CHECK_COUNT=${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}
      NVIDIA_DEVICE_PLUGIN_DAEMONSET_POD_RESET_COUNT=${NVIDIA_POD_RESET_COUNT_MAX}
      break
    else
      ((NVIDIA_DEVICE_PLUGIN_DAEMONSET_WAIT_COUNT++))
      sleep 2
    fi
  done

  echo -n "Waiting for the nvidia-device-plugin-daemonset pod to become ready "
  until kubectl -n gpu-operator get pods | grep nvidia-device-plugin-daemonset | grep -q "Running"
  do
    while kubectl -n gpu-operator get pods | grep -q "The connection to the server 127.0.0.1:6443 was refused"
    do
      sleep 5
    done

    if ! kubectl -n gpu-operator get pods | grep -q nvidia-device-plugin-daemonset
    then
      echo "."
      echo "(WARNING: nvidia-device-plugin-daemonset pod not found. Continuing ...)"
      break
    fi

    if [ "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_CHECK_COUNT}" -ge "${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}" ]
    then
      if [ "${NVIDIA_DEVICE_PLUGIN_DAEMONSET_POD_RESET_COUNT}" -ge "${NVIDIA_POD_RESET_COUNT_MAX}" ]
      then
        echo "."
        echo "(WARNING: nvidia-device-plugin-daemonset pod reset to many times. Moving on ...)"
        break
      else
        echo "."
        echo "(nvidia-device-plugin-daemonset pod not running. Restarting ...)"
        echo "COMMAND: kubectl -n gpu-operator delete pods -l app=nvidia-device-plugin-daemonset"
        kubectl -n gpu-operator delete pods -l app=nvidia-device-plugin-daemonset
        NVIDIA_DEVICE_PLUGIN_DAEMONSET_CHECK_COUNT=0
        ((NVIDIA_DEVICE_PLUGIN_DAEMONSET_POD_RESET_COUNT++))
      fi
    fi

    ((NVIDIA_DEVICE_PLUGIN_DAEMONSET_CHECK_COUNT++))
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  #---------------------------------------------------------------------------
  case ${NVIDIA_OPERATOR_VALIDATOR_ENABLED} in
    True|true|T|TRUE|Y|YES|y|yes)
      local NVIDIA_OPERATOR_VALIDATOR_WAIT_COUNT=0
      local NVIDIA_OPERATOR_VALIDATOR_CHECK_COUNT=0
      local NVIDIA_OPERATOR_VALIDATOR_POD_RESET_COUNT=0

      echo "Waiting for the nvidia-operator-validator pod to start ... "
      until kubectl -n gpu-operator get pods | grep -q nvidia-operator-validator
      do
        if [ "${NVIDIA_OPERATOR_VALIDATOR_WAIT_COUNT}" -ge "${NVIDIA_POD_WAIT_COUNT_MAX}" ]
        then
          echo "(WARNING: Exceeded wait time for nvidia-operator-validator pod to start. Moving on ...)"
          NVIDIA_OPERATOR_VALIDATOR_CHECK_COUNT=${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}
          NVIDIA_OPERATOR_VALIDATOR_POD_RESET_COUNT=${NVIDIA_POD_RESET_COUNT_MAX}
          break
        else
          ((NVIDIA_OPERATOR_VALIDATOR_WAIT_COUNT++))
          sleep 2
        fi
      done

      echo -n "Waiting for the nvidia-operator-validator pod to become ready "
      local NVIDIA_OPERATOR_VALIDATOR_CHECK_COUNT=0
      local NVIDIA_OPERATOR_VALIDATOR_POD_RESET_COUNT=0
      until kubectl -n gpu-operator get pods | grep nvidia-operator-validator | grep -q "Running"
      do
        while kubectl -n gpu-operator get pods | grep -q "The connection to the server 127.0.0.1:6443 was refused"
        do
          sleep 5
        done

        if ! kubectl -n gpu-operator get pods | grep -q nvidia-operator-validator
        then
          echo "."
          echo "(WARNING: nvidia-operator-validator pod no longer found. Continuing ...)"
          break
        fi

        if [ "${NVIDIA_OPERATOR_VALIDATOR_CHECK_COUNT}" -ge "${NVIDIA_POD_RUNNING_CHECK_COUNT_MAX}" ]
        then
          if [ "${NVIDIA_OPERATOR_VALIDATOR_POD_RESET_COUNT}" -ge "${NVIDIA_POD_RESET_COUNT_MAX}" ]
          then
            echo "."
            echo "WARNING: nvidia-operator-validator pod reset to many times. Moving on ...)"
            break
          else
            echo "."
            echo "(nvidia-operator-validator pod not running. Restarting ...)"
            echo "COMMAND: kubectl -n gpu-operator delete pods -l app=nvidia-operator-validator"
            kubectl -n gpu-operator delete pods -l app=nvidia-operator-validator
            NVIDIA_OPERATOR_VALIDATOR_CHECK_COUNT=0
            ((NVIDIA_OPERATOR_VALIDATOR_POD_RESET_COUNT++))
          fi
        fi

        ((NVIDIA_OPERATOR_VALIDATOR_CHECK_COUNT++))
        echo -n "."
        sleep 2
      done
      echo "."
      echo
    ;;
  esac

  echo "Waiting for the metadata labels to be created/updated ..."
  sleep 15
  echo
}

label_gpu_nodes() {
  echo "Labeling GPU nodes ..."
  for NODE in $(kubectl get nodes | grep -v ^NAME | awk '{ print $1 }')
  do
    echo "---------------------"
    echo "Node: ${NODE}"
    echo "---------------------"
    #if kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "nvidia.com/gpu.machine"
    if lspci | grep -qi "nvidia"
    then
      echo GPU_NODE=true
      echo

      if ! kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "accelerator"
      then
        echo "COMMAND: kubectl label node ${NODE} accelerator=nvidia-gpu"
        kubectl label node ${NODE} accelerator=nvidia-gpu
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

verify_nvidia_gpu_operator_deployment() {
  echo
  echo "Verifying nvidia-gpu-operator deployment:"
  for NODE in $(kubectl get nodes | grep -v ^NAME | awk '{ print $1 }')
  do
    echo "---------------------"
    echo "Node: ${NODE}"
    echo "---------------------"
    if kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "nvidia.com/gpu.machine"
    then
#      echo GPU_NODE=true
#      echo
#
#      if ! kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "accelerator"
#      then
#        echo "COMMAND: kubectl label node ${NODE} accelerator=nvidia-gpu"
#        kubectl label node ${NODE} accelerator=nvidia-gpu
#        echo
#      fi
#
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "accelerator""
      kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "accelerator"
      echo
 
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/gpu.machine""
      kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/gpu.machine"
      echo
 
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/cuda.driver.major""
      kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/cuda.driver.major"
      echo
 
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.status.allocatable}' | jq "
      kubectl get node ${NODE} -o jsonpath='{.status.allocatable}' | jq 
      echo

      if hostname | grep -q ${NODE}
      then
        echo "COMMAND: ls /usr/local/nvidia/toolkit/nvidia-container-runtime"
        ls /usr/local/nvidia/toolkit/nvidia-container-runtime
        echo
        echo "COMMAND: grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml"
        grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml
      else
        echo "COMMAND: ssh root@${NODE} 'ls /usr/local/nvidia/toolkit/nvidia-container-runtime;grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'"
        ssh root@${NODE} 'ls /usr/local/nvidia/toolkit/nvidia-container-runtime;grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'
      fi

      #echo "COMMAND: ssh root@${NODE} 'grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'"
      #sh root@${NODE} 'grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'
      echo
      echo
#    else
#      echo GPU_NODE=false
#      echo
#      echo "Note: If you think this is incorrect wait about 10-15 seconds and run"
#      echo "      this script again. The metadata labels may not have been updated yet."
#      echo
    fi
done
}

write_out_gpu_time_slicing_config() {
  echo "Writing out nvidia-gpu-time-slicing-config.yaml ..."
  echo
  echo "apiVersion: v1
kind: ConfigMap
metadata:
  name: time-slicing-config
  namespace: gpu-operator
data:
  any: |-
    version: v1
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: ${NVIDIA_GPU_TIMESLICE_REPLICAS}
" > nvidia-gpu-time-slicing-config.yaml
  echo
  cat nvidia-gpu-time-slicing-config.yaml
  echo
}

enable_nvidia_gpu_timeslicing() {
  echo "Enabling NVIDIA GPU Time Slicing ..."
  echo

  if [ -e nvidia-gpu-time-slicing-config.yaml ]
  then
    echo "COMMAND: kubectl -n gpu-operator apply -f nvidia-gpu-time-slicing-config.yaml"
    kubectl -n gpu-operator apply -f nvidia-gpu-time-slicing-config.yaml
    echo
  else
    echo "nvidia-gpu-time-slicing-config.yaml does not exist. Skipping ..."
    echo
  fi

  local GPU_CLUSTER_POLICY_NAME=$(kubectl -n gpu-operator get clusterpolicies.nvidia.com | grep policy | awk '{ print $1 }')

  if ! kubectl -n gpu-operator describe clusterpolicies cluster-policy | grep -q time-slicing-config
  then
    echo "COMMAND: kubectl -n gpu-operator patch clusterpolicies/cluster-policy --type=merge --patch '{\"spec\": {\"devicePlugin\": {\"config\": {\"name\": \"time-slicing-config\", \"default\": \"any\"}}}}'"
    kubectl -n gpu-operator patch clusterpolicies/cluster-policy --type=merge --patch '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config", "default": "any"}}}}'
    echo
  fi
  
  kubectl describe nodes | grep "^  nvidia.com/gpu:" | head -1
  echo
}

usage() {
  echo
  echo "USAGE: ${0} [custom_overrides_only|install_only|label_nodes_only|verify_only|configure_time_slicing_only]"
  echo
  echo "Options: "
  echo "    custom_overrides_only       (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "    install_only                (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo "    label_nodes_only            (only label the GPU nodes)"
  echo "    verify_only                 (only display verification of the GPU nodes)"
  echo "    with_time_slicing           (install with GPU time slicing)"
  echo "    configure_time_slicing_only (only configure GPU timeslicing)"
  echo
  echo "If no option is supplied the ${CUSTOM_OVERRIDES_FILE} file is created and"
  echo "is used to perform an installation using 'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo "         ${0} label_nodes_only"
  echo "         ${0} verify_only"
  echo "         ${0} with_time_slicing"
  echo "         ${0} configue_time_slicing_only"
  echo
}

##############################################################################

case ${1} in
  manifest_only)
    write_out_nvidia_gpu_operator_helm_operator_manifest_file
    display_nvidia_operator_helm_operator_manifest_file
  ;;
  custom_overrides_only)
    write_out_nvidia_gpu_operator_custom_overrides_file
    display_nvidia_gpu_operator_custom_overrides_file
  ;;
  configure_time_slicing_only)
    write_out_gpu_time_slicing_config
    enable_nvidia_gpu_timeslicing
  ;;
  #-----
  install_only)
    check_for_kubectl
    check_for_helm
    label_gpu_nodes
    if ! kubectl get pods -A | grep -q nvidia-operator-validator
    then
      display_nvidia_gpu_operator_custom_overrides_file
      deploy_nvidia_gpu_operator
      check_nvidia_gpu_operator_deployment_status
    fi
    verify_nvidia_gpu_operator_deployment
    write_out_gpu_time_slicing_config
    enable_nvidia_gpu_timeslicing
  ;;
  install_only_via_helm_operator)
    check_for_kubectl
    label_gpu_nodes
    if ! kubectl get pods -A | grep -q nvidia-operator-validator
    then
      display_nvidia_operator_helm_operator_manifest_file
      deploy_nvidia_gpu_operator_via_the_helm_operator
      check_nvidia_gpu_operator_deployment_status
    fi
    verify_nvidia_gpu_operator_deployment
    write_out_gpu_time_slicing_config
    enable_nvidia_gpu_timeslicing
  ;;
  #-----
  via_helm_operator)
    check_for_kubectl
    label_gpu_nodes
    if ! kubectl get pods -A | grep -q nvidia-operator-validator
    then
      write_out_nvidia_gpu_operator_helm_operator_manifest_file
      display_nvidia_operator_helm_operator_manifest_file
      deploy_nvidia_gpu_operator_via_the_helm_operator
      check_nvidia_gpu_operator_deployment_status
    fi
    verify_nvidia_gpu_operator_deployment
    write_out_gpu_time_slicing_config
    enable_nvidia_gpu_timeslicing
  ;;
  #-----
  label_nodes_only)
    check_for_kubectl
    label_gpu_nodes
    #if kubectl get pods -A | grep -q nvidia-operator-validator
    #then
    #  label_gpu_nodes
    #fi
  ;;
  #-----
  verify_only)
    check_for_kubectl
    if kubectl get pods -A | grep -q nvidia-operator-validator
    then
      verify_nvidia_gpu_operator_deployment
    fi
  ;;
  with_time_slicing)
    check_for_kubectl
    check_for_helm
    label_gpu_nodes
    if ! kubectl get pods -A | grep -q nvidia-operator-validator
    then
      write_out_nvidia_gpu_operator_custom_overrides_file
      display_nvidia_gpu_operator_custom_overrides_file
      deploy_nvidia_gpu_operator
      check_nvidia_gpu_operator_deployment_status
    fi
    verify_nvidia_gpu_operator_deployment
    write_out_gpu_time_slicing_config
    enable_nvidia_gpu_timeslicing
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    label_gpu_nodes
    if ! kubectl get pods -A | grep -q nvidia-operator-validator
    then
      write_out_nvidia_gpu_operator_custom_overrides_file
      display_nvidia_gpu_operator_custom_overrides_file
      deploy_nvidia_gpu_operator
      check_nvidia_gpu_operator_deployment_status
    fi
    verify_nvidia_gpu_operator_deployment
  ;;
esac

