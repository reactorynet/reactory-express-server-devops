#!/bin/bash

# This script is used to prepare the minikube environment before 
# we run the terraform script.
# The script will copy the environment file to the minikube files
# as well as the grafana and prometheus dashboards and configuration
# files. The script will also copy the reactory data to the minikube
# files directory.

# check if the minikube command is available
if ! command -v minikube &> /dev/null
then
    echo "Please install minikube before running this script"
    exit 0
fi

if [ ${MINIKUBE_SKIP_FILE_COPY:-"false"} = "true" ]; then
  echo "Skipping file copy to minikube"  
  minikube stop

  if [ $MINIKUBE_DELETE_ALL = "true" ]; then
    echo "🧹 Clearing minikube"
    minikube delete --all
  fi

  if [ ! -f $ENV_FILE ]; then
    echo "Environment file $ENV_FILE not found, exiting"
    exit 0
  fi

  if [ ! -d $MINKUBE_FILES ]; then
    echo "Minikube files directory $MINKUBE_FILES not found, exiting"
    exit 0
  fi

  if [ ! -d "$MINIKUBE_FILES/etc/reactory" ]; then
    echo "🛠️ Creating reactory data directory for minikube"
    mkdir -p $MINIKUBE_FILES/etc/reactory
  fi

  if [ ! -d "$MINIKUBE_FILES/etc/grafana" ]; then
    echo "🛠️ Creating grafana data directory for minikube"
    mkdir -p "$MINIKUBE_FILES/etc/grafana"
  fi

  if [ ! -d "$MINIKUBE_FILES/etc/prometheus" ]; then
    echo "🛠️ Creating prometheus data directory for minikube"
    mkdir -p "$MINIKUBE_FILES/etc/prometheus"
  fi

  if [ ! -d $MINIKUBE_FILES/var/reactory-data ]; then
    echo "🛠️ Creating reactory data directory for minikube"
    mkdir -p "$MINIKUBE_FILES/var/reactory-data"
  fi

  # copy certificates from the src/certificates directory to the minikube directory
  echo "Checking for certificates in $REACTORY_SERVER/config/$REACTORY_CONFIG/certs"

  if [ -d "$REACTORY_SERVER/config/$REACTORY_CONFIG/certs" ]; then
    echo "🛠️ Synchronizing certificates to $MINIKUBE_FILES/etc/ssl/certs"
    if [ ! -d "$MINIKUBE_FILES/etc/ssl/certs" ]; then
      echo "🛠️ Creating ssl certs directory for minikube"
      mkdir -p "$MINIKUBE_FILES/etc/ssl/certs"
    fi
    rsync -av --progress "$REACTORY_SERVER/config/$REACTORY_CONFIG/certs" "$MINIKUBE_FILES/etc/ssl"
  fi

  echo "🛠️ Copying Environment $ENV_FILE to $MINIKUBE_FILES/etc/reactory/.env"
  cp "$ENV_FILE" "$MINIKUBE_FILES/etc/reactory/.env"
  echo "🛠️ Synchronizing Grafana configuration to $MINIKUBE_FILES/etc/grafana"
  rsync -av --progress "$REACTORY_SERVER/src/modules/reactory-telemetry/data/grafana/" "$MINIKUBE_FILES/etc/grafana"
  echo "🛠️ Synchronizing Prometheus configuration to $MINIKUBE_FILES/etc/prometheus"
  rsync -av --progress "$REACTORY_SERVER/src/modules/reactory-telemetry/data/prometheus/" "$MINIKUBE_FILES/etc/prometheus"
  if [ -d "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/data" ]; then
    echo "🛠️ Synchronizing Reactory data to $MINIKUBE_FILES/var/reactory"
    rsync -av --progress "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/data/" "$MINIKUBE_FILES/var/reactory-data"
  fi
  
  # use minikube ssh to set enable write permissions for the grafana and prometheus directories
  minikube ssh "sudo chmod -R 777 /etc/grafana"
  minikube ssh "sudo chmod -R 777 /etc/prometheus"

  minikube start
fi

echo "🛠️ Loading images into minikube"
echo "Loading $REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/express-server-image.tar"
minikube image load "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/express-server-image.tar"
echo "Loading $REACTORY_CLIENT/build/$REACTORY_CONFIG/$REACTORY_ENV/pwa-client-image.tar"
minikube image load "$REACTORY_CLIENT/build/$REACTORY_CONFIG/$REACTORY_ENV/pwa-client-image.tar"


echo "🛠️ Minikube environment is ready for terraform"
# set the default namespace on minikube to reactory.
kubectl config set-context --current --namespace=reactory