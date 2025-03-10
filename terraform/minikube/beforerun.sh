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

# check if the minikube profile is set
if [ -z "$REACTORY_CONFIG" ]; then
  echo "Please set the REACTORY_CONFIG environment variable"
  exit 0
fi


if [ ! -f $ENV_FILE ]; then
  echo "Environment file $ENV_FILE not found, exiting"
  exit 0
fi

if [ ! -d $MINKUBE_FILES ]; then
  echo "Minikube files directory $MINKUBE_FILES not found, exiting"
  exit 0
fi


if [ $MINIKUBE_DELETE_ALL -eq 1 ]; then
  minikube stop --profile $REACTORY_CONFIG
  echo "🗑️ Deleting minikube profile $REACTORY_CONFIG"
  minikube delete --profile $REACTORY_CONFIG
  # delete the terraform state file and backup files
  rm -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/terraform.tfstate*

  # use minikube ssh to set enable write permissions for the grafana and prometheus directories
  echo "🚀 Starting minikube $REACTORY_CONFIG"
  minikube start  --profile $REACTORY_CONFIG \
                --memory=${MINIKUBE_MEMORY:-8192} \
                --cpus=${MINIUKE_CPUS:-4} \
                --disk-size=${MINIKUBE_DISK_SIZE:-50g} \
                --driver=${MINIKUBE_DRIVER:-parallels}
fi

# mount certificates from the configuration directory
if [ -d "$REACTORY_SERVER/config/$REACTORY_CONFIG/certs" ]; then
  echo "🛠️ Archiving certificates"
  tar --exclude='._*' -czf /tmp/certs.tar.gz -C "$REACTORY_SERVER/config/$REACTORY_CONFIG/certs" .
  echo "🛠️ Copying certificates archive to minikube"
  minikube cp /tmp/certs.tar.gz /tmp/certs.tar.gz --profile $REACTORY_CONFIG
  echo "🛠️ Extracting certificates in minikube"
  minikube ssh "sudo mkdir -p /etc/ssl/certs && sudo tar -xzf /tmp/certs.tar.gz -C /etc/ssl/certs && sudo rm /tmp/certs.tar.gz" --profile $REACTORY_CONFIG --native-ssh
  rm /tmp/certs.tar.gz
fi

minikube ssh "sudo mkdir -p /etc/reactory" --profile $REACTORY_CONFIG --native-ssh

source $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/$REACTORY_ENV/filesync.sh

synch_files $REACTORY_CONFIG $REACTORY_ENV $ENV_FILE 0

minikube addons enable istio-provisioner --profile $REACTORY_CONFIG
minikube addons enable istio --profile $REACTORY_CONFIG

minikube ssh "sudo chmod -R 777 /etc/grafana" --profile $REACTORY_CONFIG --native-ssh
minikube ssh "sudo chmod -R 777 /etc/prometheus" --profile $REACTORY_CONFIG --native-ssh

echo "🛠️ Loading images into minikube for profile $REACTORY_CONFIG"
echo "Loading $REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/express-server-image.tar"
minikube image load "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/express-server-image.tar" --profile $REACTORY_CONFIG
echo "Loading $REACTORY_CLIENT/build/$REACTORY_CONFIG/$REACTORY_ENV/pwa-client-image.tar"
minikube image load "$REACTORY_CLIENT/build/$REACTORY_CONFIG/$REACTORY_ENV/pwa-client-image.tar" --profile $REACTORY_CONFIG

# set the default namespace on minikube to reactory.
kubectl config set-context --current --namespace=$REACTORY_CONFIG
# configure istio injection for the namespace
kubectl label namespace $REACTORY_CONFIG istio-injection=enabled --overwrite

# copy the contents tmp file to the hosts file
echo "🛠️ Minikube environment is ready for terraform"