#!/bin/bash

##############################################################################

# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_observability_client.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
fi
else
  CLUSTER_NAME=c01
  OTEL_NAMESPACE=opentelemetry-collector
  OTEL_HELM_REPO=https://open-telemetry.github.io/opentelemetry-helm-charts
  OTEL_VERSION=
fi

LICENSES_FILE=../authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=otel_custom_overrides.yaml

##############################################################################
#   Functions
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

log_into_app_collection() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi


  echo "Logging into the Application Collection ..."
  echo "COMMAND: helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}"
  helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}
  echo
}

create_app_collection_secret() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi

  if ! [ -z ${OTEL_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${OTEL_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${OTEL_NAMESPACE}"
      kubectl create namespace ${OTEL_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${OTEL_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${OTEL_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} get secrets"
      kubectl -n ${OTEL_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${OTEL_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${OTEL_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${OTEL_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} get secrets"
      kubectl -n ${OTEL_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${OTEL_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  else
    if ! kubectl get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl get secrets"
      kubectl get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl get secrets"
      kubectl get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  fi
}

patch_serviceaccounts() {
  #echo COMMAND: kubectl patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  #kubectl patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  #echo

  echo COMMAND: kubectl -n ${OTEL_NAMESPACE} patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  kubectl -n ${OTEL_NAMESPACE} patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  echo
}

create_otel_secret() {
  if ! [ -z ${OTEL_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${OTEL_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${OTEL_NAMESPACE}"
      kubectl create namespace ${OTEL_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${OTEL_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q open-telemetry-collector
    then
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_INSTALLATION_API_KEY}"
      kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_INSTALLATION_API_KEY}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} get secrets"
      kubectl -n ${OTEL_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector"
      kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} delete secret open-telemetry-collector"
      kubectl -n ${OTEL_NAMESPACE} delete secret open-telemetry-collector
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_INSTALLATION_API_KEY}"
      kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_INSTALLATION_API_KEY}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} get secrets"
      kubectl -n ${OTEL_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector"
      kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  fi
}

create_otel_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo

  rm ${CUSTOM_OVERRIDES_FILE}

  if ! [ -z ${OTEL_HELM_CHART} ]
  then
    echo "global:
  imagePullSecrets:
  - application-collection">> ${CUSTOM_OVERRIDES_FILE}
  fi

  echo "
extraEnvsFrom:
  - secretRef:
      name: open-telemetry-collector
mode: deployment">> ${CUSTOM_OVERRIDES_FILE}

  if [ -z ${OTEL_HELM_CHART} ]
  then
    echo "image:
  repository: \"otel/opentelemetry-collector-k8s\"">> ${CUSTOM_OVERRIDES_FILE}
    if ! [ -z ${OTEL_VERSION} ]
    then
      echo "  tag: ${OTEL_VERSION}">> ${CUSTOM_OVERRIDES_FILE}
    fi
  fi

  echo "ports:
  metrics:
    enabled: true
presets:
  kubernetesAttributes:
    enabled: true
    extractAllPodLabels: true
config:" >> ${CUSTOM_OVERRIDES_FILE}

  if [[ "${OTEL_GPU_METRICS_ENABLED}" == "True" || "${OTEL_MILVUS_METRICS_ENABLED}" == "True" ]]
  then
    echo "  receivers:
    prometheus:
      config:
        scrape_configs:" >> ${CUSTOM_OVERRIDES_FILE}
  fi

  case ${OTEL_GPU_METRICS_ENABLED} in
    True|TRUE|true)
      echo "          - job_name: 'gpu-metrics'
            scrape_interval: 10s
            scheme: http
            kubernetes_sd_configs:
              - role: endpoints
                namespaces:
                  names:
                    - gpu-operator" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  case ${OTEL_MILVUS_METRICS_ENABLED} in
    True|TRUE|true)
      echo "          - job_name: 'milvus'
            scrape_interval: 15s
            metrics_path: '/metrics'
            static_configs:
              - targets: ['${OTEL_MILVUS_SERVICE_NAME}.${SUSE_AI_NAMESPACE}.svc.cluster.local:9091']" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  echo "  exporters:
    otlp:
      endpoint: http://${OBSERVABILITY_OTLP_HOST}:${OBSERVABILITY_OTLP_INGRESS_PORT}
      headers:
        Authorization: \"SUSEObservability \${env:API_KEY}\"
      tls:
        insecure: true
  processors:
    tail_sampling:
      decision_wait: 10s
      policies:
      - name: rate-limited-composite
        type: composite
        composite:
          max_total_spans_per_second: 500
          policy_order: [errors, slow-traces, rest]
          composite_sub_policy:
          - name: errors
            type: status_code
            status_code:
              status_codes: [ ERROR ]
          - name: slow-traces
            type: latency
            latency:
              threshold_ms: 1000
          - name: rest
            type: always_sample
          rate_allocation:
          - policy: errors
            percent: 33
          - policy: slow-traces
            percent: 33
          - policy: rest
            percent: 34
    resource:
      attributes:
      - key: k8s.cluster.name
        action: upsert
        value: ${CLUSTER_NAME}
      - key: service.instance.id
        from_attribute: k8s.pod.uid
        action: insert
      - key: service.namespace
        from_attribute: k8s.namespace.name
        action: insert
    filter/dropMissingK8sAttributes:
      error_mode: ignore
      traces:
        span:
          - resource.attributes[\"k8s.node.name\"] == nil
          - resource.attributes[\"k8s.pod.uid\"] == nil
          - resource.attributes[\"k8s.namespace.name\"] == nil
          - resource.attributes[\"k8s.pod.name\"] == nil
  connectors:
    spanmetrics:
      metrics_expiration: 5m
      namespace: otel_span
    routing/traces:
      error_mode: ignore
      table:
      - statement: route()
        pipelines: [traces/sampling, traces/spanmetrics]
  service:
    extensions:
      - health_check
    pipelines:
      traces:
        receivers: [otlp, jaeger]
        processors: [filter/dropMissingK8sAttributes, memory_limiter, resource]
        exporters: [routing/traces]
      traces/spanmetrics:
        receivers: [routing/traces]
        processors: []
        exporters: [spanmetrics]
      traces/sampling:
        receivers: [routing/traces]
        processors: [tail_sampling, batch]
        exporters: [debug, otlp]
      metrics:
        receivers: [otlp, spanmetrics, prometheus]
        processors: [memory_limiter, resource, batch]
        exporters: [debug, otlp]" >> ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

create_otel_rbac_manifest() {
  echo "Writing out otel-rbac.yaml file ..."
  echo
  echo "
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: suse-observability-otel-scraper
rules:
  - apiGroups:
      - \"\"
    resources:
      - services
      - endpoints
    verbs:
      - list
      - watch
      - get

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: suse-observability-otel-scraper
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: suse-observability-otel-scraper
subjects:
  - kind: ServiceAccount
    name: opentelemetry-collector
    namespace: ${OTEL_NAMESPACE}
  " > otel-rbac.yaml
  echo
  cat otel-rbac.yaml
}

install_opentelemetry_collector() {
  if ! [ -z ${OTEL_VERSION} ]
  then
    local OTEL_VER_ARG="--version ${OTEL_VERSION}"
  fi

  echo "Installing the OpenTelemetry Collector ..."
  echo "------------------------------------------------------------"

  if [ -z ${OTEL_HELM_CHART} ]
  then
    echo "COMMAND: helm repo add open-telemetry ${OTEL_HELM_REPO}"
    helm repo add open-telemetry ${OTEL_HELM_REPO}
 
    echo "COMMAND: helm repo update"
    helm repo update
    echo
 
    echo "image:
  repository: \"otel/opentelemetry-collector-k8s\"" >> ${CUSTOM_OVERRIDES_FILE}

    echo "COMMAND: helm upgrade --install opentelemetry-collector --namespace ${OTEL_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} open-telemetry/opentelemetry-collector ${OTEL_VER_ARG}"
    helm upgrade --install opentelemetry-collector --namespace ${OTEL_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} open-telemetry/opentelemetry-collector ${OTEL_VER_ARG}
    echo
  else
    log_into_app_collection
    create_app_collection_secret
    #patch_serviceaccounts
    #create_otel_custom_overrides_file
    #display_custom_overrides_file

    echo "COMMAND: helm upgrade --install opentelemetry-collector ${OTEL_HELM_CHART} --namespace ${OTEL_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${OTEL_VER_ARG}"
    helm upgrade --install opentelemetry-collector ${OTEL_HELM_CHART} --namespace ${OTEL_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} ${OTEL_VER_ARG}
    
  fi

  echo
}

configure_otel_gpu_rbac() {
  echo "Configuring OpenTelemetry RBAC ..."
  echo
  echo "COMMAND: kubectl apply -n gpu-operator -f otel-rbac.yam"l
  kubectl apply -n gpu-operator -f otel-rbac.yaml
  echo
}


usage() {
  echo 
  echo "USAGE: ${0} [custom_overrides_only|install_only]"
  echo 
  echo "Options: "
  echo "    custom_overrides_only  (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "    install_only           (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo
  echo "If no option is supplied the ${CUSTOM_OVERRIDES_FILE} file is created and"
  echo "is used to perform an installation using 'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo 
}

##############################################################################

case ${1} in
  custom_overrides_only)
    check_for_kubectl
    check_for_helm
    create_otel_custom_overrides_file
    display_custom_overrides_file
    create_otel_rbac_manifest
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    create_otel_secret
    install_opentelemetry_collector
    case ${OTEL_GPU_METRICS_ENABLED} in
      True|TRUE|true)
        configure_otel_gpu_rbac
      ;;
    esac
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    create_otel_secret
    create_otel_custom_overrides_file
    display_custom_overrides_file
    install_opentelemetry_collector
    case ${OTEL_GPU_METRICS_ENABLED} in
      True|TRUE|true)
        create_otel_rbac_manifest
        configure_otel_gpu_rbac
      ;;
    esac
  ;;
esac

