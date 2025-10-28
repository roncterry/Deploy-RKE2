#!/bin/bash

POD_LIST="gpu-feature-discovery nvidia-dcgm-exporter nvidia-device-plugin-daemonset nvidia-operator-validator"

echo
echo "========================================================================"
echo "Resetting non-running NVIDIA GPU Operator pods ..."
echo "========================================================================"
for POD in ${POD_LIST}
do
  if ! kubectl -n gpu-operator get pods | grep ${POD} | grep -q "Running"
  then
    echo "Resetting pod: ${POD}"
    echo "--------------------------------------------------------------------"
    echo "COMMAND: kubectl -n gpu-operator delete pods -l app=${POD}"
    kubectl -n gpu-operator delete pods -l app=${POD}
    echo
  else
    echo "Pod ${POD} is running. Continuing ..."
  fi
done
