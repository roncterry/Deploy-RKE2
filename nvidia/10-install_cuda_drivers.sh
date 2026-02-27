#!/bin/bash

SLE_VER="$(grep "VERSION=.*" /etc/os-release | cut -d \" -f 2 | cut -d - -f 1 | cut -d . -f 1)"
CUDA_REPO="https://developer.download.nvidia.com/compute/cuda/repos/sles${SLE_VER}/x86_64/"

install_nvidia_drivers() {
  echo
  echo "=============================================================================="
  echo "                     Installing NVIDIA CUDA Drivers"
  echo "=============================================================================="

  if zypper lr | grep -q NVIDIA
  then
    for NV_REPO in zypper lr | grep NVIDIA | awk '{ print $5 }'
    do
      echo "COMMAND: zypper mr -e ${NV_REPO}"
      zypper mr -e ${NV_REPO}
    done
    echo
  else
    echo "COMMAND: zypper ar ${CUDA_REPO} cuda-sle${SLE_VER}"
    zypper ar ${CUDA_REPO} cuda-sle${SLE_VER}
    echo
  fi

  echo
  echo "COMMAND: zypper --gpg-auto-import-keys refresh"
  zypper --gpg-auto-import-keys refresh

  echo
  echo "COMMAND: zypper remove -y *nvidia*"
  zypper remove -y *nvidia*

  echo
  echo "COMMAND: zypper install -y --auto-agree-with-licenses nv-prefer-signed-open-driver"
  zypper install -y --auto-agree-with-licenses nv-prefer-signed-open-driver

  DRIVER_VERSION=$(rpm -qa --queryformat '%{VERSION}\n' nv-prefer-signed-open-driver | cut -d "_" -f1 | sort -u | tail -n 1)

  if zypper se nvidia-open-driver | grep ^i | awk '{ print $3 }' | grep -q G06
  then
  echo
    echo "COMMAND: zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06=${DRIVER_VERSION}"
    zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06=${DRIVER_VERSION}
  echo
  elif zypper se nvidia-open-driver | grep ^i | awk '{ print $3 }' | grep -q G07
  then
    echo "COMMAND: zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G07=${DRIVER_VERSION}"
    zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G07=${DRIVER_VERSION}
  fi
  echo
}

run_nvidia_smi() {
  echo
  echo "COMMAND: nvidia-smi"
  nvidia-smi
  echo
}

##############################################################################

if lspci | grep -qi nvidia
then
  install_nvidia_drivers
  run_nvidia_smi
elif echo ${*} | grep -q "--force"
  echo
  echo "ERROR: No NVIDIA GPU found. Installing the drivers anyway."
  echo
  install_nvidia_drivers
else
  echo
  echo "ERROR: No NVIDIA GPU found. Exiting."
  echo
fi

