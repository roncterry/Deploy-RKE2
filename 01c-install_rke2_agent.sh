#!/bin/bash

# You can either source in the variables from a common config file or
# set them in this script.

CONFIG_FILE=deploy_rke2.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  FS_INOTIFY_MAX_USER_INSTANCES=1024
  K8S_DISTRO=rke2
  K8S_DISTRO_CHANNEL=v1.30
  CLUSTER_NAME=aicluster01
  CLUSTER_TOKEN=${CLUSTER_NAME}
  DOMAIN_NAME=example.com
  BUILTIN_INGRESS_CONTROLLER=ingress-nginx
  DISABLED_BUILTIN_SERVICE_LIST=
  INSTALL_EXTERNAL_INGRESS_CONTROLLER=false
  EXTERNAL_INGRESS_CONTROLLER_NAMESPACE=kube-system
  EXTERNAL_INGRESS_CONTROLLER_KIND=DaemonSet
  EXTERNAL_INGRESS_CONTROLLER_REPLICAS=1
  INSTALL_RKE2_KUBEVIP=false
  RKE2_CLUSTER_VIP_KUBEVIP_HELM_REPO="https://kube-vip.github.io/helm-charts"
  RKE2_CLUSTER_VIP_KUBEVIP_VERSION=
  RKE2_CLUSTER_VIP_NAMESPACE=kube-vip
  RKE2_CLUSTER_VIP=
  RKE2_CLUSTER_VIP_INTERFACE=
  RKE2_CLUSTER_VIP_CP_ENABLE=true
  RKE2_CLUSTER_VIP_LEADERELECTION=true
  RKE2_CLUSTER_VIP_HOSTNAME=
fi

#------------------------------------------------------------------------------

# The NODE_TYPE variable must be set in this script.
# Options: server, agent
#
NODE_TYPE=agent

# The FIRST_SERVER must be set to 'true' for the initial server node and 
# 'false' for all other server nodes. This variable must be set in this script.
# This is ignored if NODE_TYPE=agent
#
FIRST_SERVER=false

###############################################################################
#   Functions
###############################################################################

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

#create_kubevip_rke2_helm_manifest() {
#  echo "COMMAND: mkdir -p /var/lib/rancher/rke2/server/manifests/"
#  mkdir -p /var/lib/rancher/rke2/server/manifests/
#
#  echo "
#apiVersion: helm.cattle.io/v1
#kind: HelmChart
#metadata:
#  name: kube-vip
#  namespace: kube-system
#spec:
#  chart: kube-vip
#  repo: https://kube-vip.github.io/helm-charts
#  targetNamespace: ${RKE2_CLUSTER_VIP_NAMESPACE}
#  valuesContent: |-
#    hostNetwork: true
#    tolerations:
#      - effect: NoSchedule
#        operator: Exists
#      - effect: NoExecute
#        operator: Exists
#    config:
#      address: \"${RKE2_CLUSTER_VIP}\"
#    env:
#      vip_arp: \"true\"
#      vip_interface: \"${RKE2_CLUSTER_VIP_INTERFACE}\"
#      cp_enable: \"${RKE2_CLUSTER_VIP_CP_ENABLE}\"
#      vip_leaderelection: \"${RKE2_CLUSTER_VIP_LEADERELECTION}\"
#    nodeSelector:
#      node-role.kubernetes.io/control-plane: \"${RKE2_CLUSTER_VIP_CP_ENABLE}\"" > /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
#}

install_k8s_distro() {
  echo "Setting sysctl fs.inotify.max_user_instances=${FS_INOTIFY_MAX_USER_INSTANCES}"
  echo "fs.inotify.max_user_instances=${FS_INOTIFY_MAX_USER_INSTANCES}" > /etc/sysctl.d/50-fs_inotify_max_user_instances.conf
  sysctl fs.inotify.max_user_instances=${FS_INOTIFY_MAX_USER_INSTANCES}
  echo

  echo "Downloading ${K8S_DISTRO} installer ..."
  echo "COMMAND: curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh"
  curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh

  echo "COMMAND: chmod +x /root/${K8S_DISTRO}-install.sh"
  chmod +x /root/${K8S_DISTRO}-install.sh
  echo

  echo "COMMAND: mkdir -p /etc/rancher/${K8S_DISTRO}"
  mkdir -p /etc/rancher/${K8S_DISTRO}
  echo

  echo "Writing out /etc/rancher/${K8S_DISTRO}/config.yaml file ..."
  case ${NODE_TYPE} in
    server)
      echo "COMMAND: mkdir -p /etc/rancher/${K8S_DISTRO}/server/manifests"
      mkdir -p /etc/rancher/${K8S_DISTRO}/server/manifests
      echo

      case ${FIRST_SERVER} in
        true)
          echo "token: ${CLUSTER_TOKEN}" > /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          #echo "- ${HOSTNAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "- ${CLUSTER_NAME}.${DOMAIN_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          if ! [ -z ${RKE2_CLUSTER_VIP} ]
          then
            echo "- $(echo ${RKE2_CLUSTER_VIP} | cut -d / -f 1)" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          fi
          if ! [ -z ${RKE2_CLUSTER_VIP_HOSTNAME} ]
          then
            echo "- $(echo ${RKE2_CLUSTER_VIP_HOSTNAME} | cut -d / -f 1)" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          fi
          echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "ingress-controller: ${BUILTIN_INGRESS_CONTROLLER}" >> /etc/rancher/${K8S_DISTRO}/config.yaml

          #case ${INSTALL_KUBEVIP} in
          #  true)
          #    create-kubevip-manifest
          #  ;;
          #esac
        ;;
        *)
          echo "server: https://${CLUSTER_NAME}.${DOMAIN_NAME}:9345" > /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "token: ${CLUSTER_TOKEN}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          #echo "- ${HOSTNAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "- ${CLUSTER_NAME}.${DOMAIN_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          if ! [ -z ${RKE2_CLUSTER_VIP} ]
          then
            echo "- $(echo ${RKE2_CLUSTER_VIP} | cut -d / -f 1)" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          fi
          if ! [ -z ${RKE2_CLUSTER_VIP_HOSTNAME} ]
          then
            echo "- $(echo ${RKE2_CLUSTER_VIP_HOSTNAME} | cut -d / -f 1)" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          fi
          echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "ingress-controller: ${BUILTIN_INGRESS_CONTROLLER}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        ;;
      esac

      if ! [ -z ${DISABLED_BUILTIN_SERVICE_LIST} ]
      then
        echo "disabled:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        for DISABLED_SERVICE in ${DISABLED_BUILTIN_SERVICE_LIST}
        do
          echo "- ${DISABLED_SERVICE}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        done
      fi
    ;;
    agent)
      echo "server: https://${CLUSTER_NAME}.${DOMAIN_NAME}:9345" > /etc/rancher/${K8S_DISTRO}/config.yaml
      echo "token: ${CLUSTER_TOKEN}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
    ;;
  esac

  echo
  cat /etc/rancher/${K8S_DISTRO}/config.yaml
  echo

  echo "COMMAND: INSTALL_RKE2_TYPE=${NODE_TYPE} INSTALL_RKE2_CHANNEL=${K8S_DISTRO_CHANNEL} /root/${K8S_DISTRO}-install.sh"
  INSTALL_RKE2_TYPE=${NODE_TYPE} INSTALL_RKE2_CHANNEL=${K8S_DISTRO_CHANNEL} /root/${K8S_DISTRO}-install.sh
  echo

  echo "COMMAND: systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service"
  systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service
  echo
}

copy_kubeconfig_file_and_kubectl() {
  case ${NODE_TYPE} in
    server)
      echo "COMMAND: mkdir ~/.kube"
      mkdir ~/.kube
      echo

      echo "COMMAND: cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
      cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
      echo

      if [ -e "/var/lib/rancher/${K8S_DISTRO}/bin/kubectl" ]
      then
        echo "COMMAND: ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
        ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
      fi
      echo

      echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
      kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
      echo
    ;;
    agent)
      echo "COMMAND: mkdir ~/.kube"
      mkdir ~/.kube
      echo

      echo "COMMAND: scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
      scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
      echo

      echo "COMMAND: sed -i \"s/127.0.0.1:6443/${CLUSTER_NAME}.${DOMAIN_NAME}:6443/g\" ~/.kube/config"
      sed -i "s/127.0.0.1:6443/${CLUSTER_NAME}.${DOMAIN_NAME}:6443/g" ~/.kube/config
      echo

      echo "COMMAND: scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
      scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
      echo

      echo "COMMAND: chmod +x /usr/local/bin/kubectl"
      chmod +x /usr/local/bin/kubectl
      echo

      if ! zypper se bash-completion | grep open-iscsi | grep -q ^i
      then
        echo "Installing bash-completion ..."
        echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses bash-completion"
        ${SUDO_CMD} zypper install -y --auto-agree-with-licenses bash-completion
        echo
      fi

      echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
      kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
      echo
    ;;
  esac
}

wait_for_node_to_be_ready() {
  case ${NODE_TYPE} in
    server)
      echo -n "Waiting for node to be ready "
      until kubectl get nodes | grep -q " Ready"
      do
        echo -n "."
        sleep 2
      done
      echo "."
      echo

      echo "COMMAND: kubectl get nodes"
      kubectl get nodes
      echo
    ;;
  esac
}
 
wait_for_essential_cluster_services_to_be_ready() {
  echo -n "Waiting for the ingress controller to be ready "

  case ${NODE_TYPE} in
    server)
      if [ "${INSTALL_EXTERNAL_INGRESS_CONTROLLER}" == true ] && [ "${EXTERNAL_INGRESS_CONTROLLER_TYPE}" == Deployment ]
      then
        local INGRESS_CONTROLLER_NAMESPACE=${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE}
        until kubectl -n ${INGRESS_CONTROLLER_NAMESPACE} get deployment | grep -v ^NAME | grep ${EXTERNAL_INGRESS_CONTROLLER} | awk '{ print $6 }' | grep -q [1-9]
        do
          echo -n "."
          sleep 2
        done
        echo "."
        echo
      elif [ "${INSTALL_EXTERNAL_INGRESS_CONTROLLER}" == true ] && [ "${EXTERNAL_INGRESS_CONTROLLER_TYPE}" == DaemonSet ]
      then
        local INGRESS_CONTROLLER_NAMESPACE=${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE}
        until kubectl -n ${INGRESS_CONTROLLER_NAMESPACE} get daemonset | grep -v ^NAME | grep ${EXTERNAL_INGRESS_CONTROLLER} | awk '{ print $6 }' | grep -q [1-9]
        do
          echo -n "."
          sleep 2
        done
        echo "."
        echo
      else
        case ${BUILTIN_INGRESS_CONTROLLER} in
          none)
            echo "(No built-in Ingress controller installed. Continuing) ..."
            echo
          ;;
          ingress-nginx|traefik)
            until kubectl -n kube-system get daemonset | grep -v ^NAME | grep ${BUILTIN_INGRESS_CONTROLLER} | awk '{ print $6 }' | grep -q [1-9]
            do
              echo -n "."
              sleep 2
            done
            echo "."
          ;;
        esac
        echo
      fi
 
      echo -n "Waiting for coredns to be ready "
      until kubectl -n kube-system get deployment | grep coredns | grep -v autoscaler | awk '{ print $4 }' | grep -q [1-9]
      do
        echo -n "."
        sleep 2
      done
      echo "."
      echo
    ;;
  esac
}

install_external_ingress_controller() {
  case ${EXTERNAL_INGRESS_CONTROLLER} in
    ingress-nginx)
      local INGRESS_HELM_REPO_URL=https://kubernetes.github.io/ingress-nginx
  
      case ${EXTERNAL_INGRESS_CONTROLLER_KIND} in
        Deployment|deployment)
          local EXT_ING_CONT_KIND_ARGS="--set controller.kind=Deployment --set controller.replicaCount=${EXTERNAL_INGRESS_CONTROLLER_REPLICAS}"
        ;;
        DaemonSet|daemonset|daemonSet)
          local EXT_ING_CONT_KIND_ARGS="--set controller.kind=DaemonSet"
        ;;
      esac
  
      echo "Installing external ingress controller ..."
      echo
      if ! kubectl get all -A | grep ingress | grep -qE '(daemonset|deployment)'
      then
        echo "COMMANDS: helm repo add ingress-nginx ${INGRESS_HELM_REPO_URL}
                helm repo update"
        helm repo add ingress-nginx ${INGRESS_HELM_REPO_URL}
        helm repo update
        echo
   
        echo "COMMAND: helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace ${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE} --create-namespace --set rbac.create=true ${EXT_ING_CONT_KIND_ARGS} --set ingressClassResource.default=true"
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace ${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE} --create-namespace --set rbac.create=true ${EXT_ING_CONT_KIND_ARGS} --set ingressClassResource.default=true
        echo
      else
        echo "(external ingress controller already installed)"
        echo
      fi
    ;;
  esac
}

create_rke2_kubevip_custom_overrides_file() {
  CUSTOM_OVERRIDES_FILE=rke2_kubevip_custom_overrides.yaml

  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
config:
  address: \"${RKE2_CLUSTER_VIP}\" 
env:
  vip_interface: \"${RKE2_CLUSTER_VIP_INTERFACE}\"
  cp_enable: \"${RKE2_CLUSTER_VIP_CP_ENABLE}\"
  vip_leaderelection: \"${RKE2_CLUSTER_VIP_LEADERELECTION}\"
nodeSelector:
  node-role.kubernetes.io/control-plane: \"${RKE2_CLUSTER_VIP_CP_ENABLE}\"" > ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_rke2_kubevip() {
  local RKE2_CLUSTER_VIP_KUBEVIP_HELM_REPO_URL=https://kube-vip.github.io/helm-charts

  if ! [ -z ${RKE2_CLUSTER_VIP_KUBEVIP_VERSION} ]
  then
    local RKE2_CLUSTER_VIP_KUBEVIP_VER_ARG="--version ${RKE2_CLUSTER_VIP_KUBEVIP_VERSION}"
  fi

  echo "Installing kube-vip ..."
  echo

  create_rke2_kubevip_custom_overrides_file
  display_custom_overrides_file

  echo "COMMAND: 
  helm repo add kube-vip ${KUBEVIP_HELM_REPO}
  helm repo update"

  echo
  echo "COMMAND: helm upgrade --install kube-vip kube-vip/kube-vip --namespace ${RKE2_CLUSTER_VIP_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${RKE2_CLUSTER_VIP_KUBEVIP_VER_ARG}"
  helm upgrade --install kube-vip kube-vip/kube-vip --namespace ${RKE2_CLUSTER_VIP_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${RKE2_CLUSTER_VIP_KUBEVIP_VER_ARG}
  echo
}

###############################################################################
#   Main Code Body
###############################################################################

install_k8s_distro
copy_kubeconfig_file_and_kubectl
wait_for_node_to_be_ready

case ${INSTALL_EXTERNAL_INGRESS_CONTROLLER} in
  true)
    check_for_helm
    install_external_ingress_controller
  ;;
esac

wait_for_essential_cluster_services_to_be_ready

case ${INSTALL_RKE2_KUBEVIP} in
  true)
    if kubectl get pods -A | grep -q kube-vip
    then
      echo
      echo "Kube-VIP is already installed. Continuing ..."
      echo
    else
      check_for_helm
      install_rke2_kubevip
    fi
  ;;
esac
 
echo "-----  The cluster is installed and running  -----"
echo
