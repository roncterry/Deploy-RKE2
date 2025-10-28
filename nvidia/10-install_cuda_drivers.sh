#!/bin/bash

SLE_VER="$(grep "VERSION=.*" /etc/os-release | cut -d \" -f 2 | cut -d - -f 1 | cut -d . -f 1)"
CUDA_REPO="https://developer.download.nvidia.com/compute/cuda/repos/sles${SLE_VER}/x86_64/"

if lspci | grep -qi nvidia
then
  echo
  echo "=============================================================================="
  echo "                     Installing NVIDIA CUDA Drivers"
  echo "=============================================================================="

  echo
  echo "COMMAND: zypper ar ${CUDA_REPO} cuda-sle${SLE_VER}"
  zypper ar ${CUDA_REPO} cuda-sle${SLE_VER}

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

  echo
  echo "COMMAND: zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06=${DRIVER_VERSION}"
  zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06=${DRIVER_VERSION}

  echo
  echo "COMMAND: nvidia-smi"
  nvidia-smi

else
  echo
  echo "ERROR: No NVIDIA GPU found. Exiting."
  echo
fi

