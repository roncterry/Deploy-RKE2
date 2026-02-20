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


install_amdgpu_driver_and_rocm() {
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
}

check_amdgpu_driver_install() {
  echo "--------------------------------------------------------------------------"
  echo "                             ROCm Info"
  echo "--------------------------------------------------------------------------"
  echo
  echo "COMMAND: rocminfo | grep -E '^=.*|^HSA.*|^\*.*|^Agent .*|ROCk module version|Runtime .*Version:|^ .Name:|Marketing Name:|Device Type:'"
  rocminfo | grep -E '^=.*|^HSA.*|^\*.*|^Agent .*|ROCk module version|Runtime .*Version:|^ .Name:|Marketing Name:|Device Type:'
  echo

  echo "--------------------------------------------------------------------------"
  echo "                            OpenCL Info"
  echo "--------------------------------------------------------------------------"
  echo
  echo "COMMAND: clinfo | grep -E 'Number of devices:|Board name:|^ .Name:|Driver version:'"
  clinfo | grep -E 'Number of devices:|Board name:|^ .Name:|Driver version:'
  echo
  echo "--------------------------------------------------------------------------"

  echo
  echo "COMMAND: amd-smi"
  amd-smi
  echo

  echo
  echo "COMMAND: rocm-smi"
  rocm-smi
  echo
  echo "##############################################################################"
}

uninstall_amdgpu_driver_and_rocm() {
  echo
  echo "=============================================================================="
  echo "                    Uninstalling AMD Radeon & ROCm Drivers"
  echo "=============================================================================="

  echo "COMMAND: zypper -n remove amdgpu-dkms andgpu-dkms-firmware rocm rocm-core amdgpu-core"
  zypper -n remove amdgpu-dkms andgpu-dkms-firmware rocm rocm-core amdgpu-core
  echo

  echo "COMMAND: zypper removerepo amdgpu"
  zypper removerepo amdgpu
  echo

  echo "COMMAND: zypper removerepo rocm"
  zypper removerepo rocm
  echo

  echo "COMMAND: zypper removerepo amdgraphics"
  zypper removerepo amdgraphics
  echo

  echo "COMMAND: zypper clean --all"
  zypper clean --all
  echo

  echo "COMMAND: zypper refresh"
  zypper refresh
  echo
}

usage() {
  echo
  echo "USAGE: ${0} [usage|help|uninstall|check]"
  echo
  echo "Options:"
  echo "    usage|help     (this message)"
  echo "    uninstall      (uninstall the driver and ROCm)"
  echo "    check          (check driver and ROCm install)"
  echo
  echo "If no options are suppplied the driver and ROCm are installed."
  echo
  echo "Example: ${0}"
  echo "         ${0} help"
  echo "         ${0} usage"
  echo "         ${0} check"
  echo "         ${0} uninstall"
  echo
}

##############################################################################

case ${1} in
  usage|-h|--help)
    usage
    exit
  ;;
  uninstall)
    uninstall_amdgpu_driver_and_rocm
  ;;
  check)
    check_amdgpu_driver_install
  ;;
  *)
    install_amdgpu_driver_and_rocm
    check_amdgpu_driver_install
  ;;
esac
