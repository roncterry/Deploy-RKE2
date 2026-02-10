#!/bin/bash

##############################################################################
# You can either source in the variables from a common config file or
# set the them in this script.

SLE_VER_ID="$(grep "VERSION_ID=" /etc/os-release | cut -d \" -f 2)"

CONFIG_FILE=deploy_amd_gpu_operator.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  AMDGPU_DRV_VER="7.2"
  AMDGPU_DRV_INST_PKG_NAME="amdgpu-install-7.2.70200-1.noarch.rpm"
  AMDGPU_PKG_URL="https://repo.radeon.com/amdgpu-install/${AMDGPU_DRV_VER}/sle/${SLE_VER_ID}/${AMDGPU_DRV_INST_PKG_NAME}"
fi

##############################################################################



echo
echo "=============================================================================="
echo "                     Installing AMD Radeon & ROCm Drivers"
echo "=============================================================================="

echo "COMMAND: zypper --no-gpg-checks install ${AMDGPU_PKG_URL}"
zypper --non-interactive --no-gpg-checks install ${AMDGPU_PKG_URL}
echo

echo "COMMAND: zypper --gpg-auto-import-keys refresh"
zypper --gpg-auto-import-keys refresh
echo

echo "COMMAND: zypper install amdgpu-dkms"
zypper --non-interactive install amdgpu-dkms
echo

echo "COMMAND: zypper install rocm"
zypper --non-interactive install rocm
echo

echo "--------------------------------------------------------------------------"
echo "                             ROCm Info"
echo "--------------------------------------------------------------------------"
echo
echo "COMMAND: rocminfo"
rocminfo
echo

echo "--------------------------------------------------------------------------"
echo "                            OpenCL Info"
echo "--------------------------------------------------------------------------"
echo
echo "COMMAND: clinfo"
clinfo
echo
echo "--------------------------------------------------------------------------"

echo
echo "COMMAND: rocm-smi"
rocm-smi
echo
echo "##############################################################################"
