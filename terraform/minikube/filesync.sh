
function synch_files() {
  REACTORY_CONFIG=${1:-"reactory"}
  REACTORY_ENV=${2:-"minikube"}
  ENV_FILE=${3:-"$REACTORY_SERVER/config/$REACTORY_CONFIG/.env.${REACTORY_ENV}"}
  SKIP_DATA=${4:-1}

  echo "🛠️ Copying Environment $ENV_FILE to $MINIKUBE_FILES/etc/reactory/.env"
  minikube cp "$ENV_FILE" "$MINIKUBE_FILES/etc/reactory/.env" --profile $REACTORY_CONFIG

  # Archive and copy Prometheus configuration
  echo "🛠️ Archiving Prometheus configuration"
  COPYFILE_DISABLE=1 tar --exclude='._*' --exclude='.DS_Store' --exclude='.AppleDouble' --exclude='.Spotlight-V100' --exclude='.Trashes' -czf /tmp/prometheus.tar.gz -C "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/app/modules/reactory-telemetry/data/prometheus" .
  echo "🛠️ Copying Prometheus archive to minikube"
  minikube cp /tmp/prometheus.tar.gz /tmp/prometheus.tar.gz --profile $REACTORY_CONFIG
  echo "🛠️ Extracting Prometheus configuration in minikube"
  minikube ssh "sudo mkdir -p /etc/prometheus" --profile $REACTORY_CONFIG --native-ssh
  minikube ssh "sudo tar -xzf /tmp/prometheus.tar.gz -C /etc/prometheus && sudo rm /tmp/prometheus.tar.gz" --profile $REACTORY_CONFIG --native-ssh
  rm /tmp/prometheus.tar.gz

  # Archive and copy Grafana configuration
  echo "🛠️ Archiving Grafana configuration"
  COPYFILE_DISABLE=1 tar --exclude='._*' --exclude='.DS_Store' --exclude='.AppleDouble' --exclude='.Spotlight-V100' --exclude='.Trashes' -czf /tmp/grafana.tar.gz -C "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/app/modules/reactory-telemetry/data/grafana" .
  echo "🛠️ Copying Grafana archive to minikube"
  minikube cp /tmp/grafana.tar.gz /tmp/grafana.tar.gz --profile $REACTORY_CONFIG
  echo "🛠️ Extracting Grafana configuration in minikube"
  # if the directory does not exist, create it
  minikube ssh "sudo mkdir -p /etc/grafana" --profile $REACTORY_CONFIG --native-ssh
  minikube ssh "sudo tar -xzf /tmp/grafana.tar.gz -C /etc/grafana && sudo rm /tmp/grafana.tar.gz" --profile $REACTORY_CONFIG --native-ssh
  rm /tmp/grafana.tar.gz

  # Archive and copy Reactory data
  if [ -d "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/data" ] && [ $SKIP_DATA -eq 0 ]; then
    echo "🛠️ Archiving Reactory data"
    COPYFILE_DISABLE=1 tar --exclude='._*' --exclude='.DS_Store' --exclude='.AppleDouble' --exclude='.Spotlight-V100' --exclude='.Trashes' -czf /tmp/reactory-data.tar.gz -C "$REACTORY_SERVER/build/server/$REACTORY_CONFIG/$REACTORY_ENV/data" .
    echo "🛠️ Copying Reactory data archive to minikube"
    minikube cp /tmp/reactory-data.tar.gz /tmp/reactory-data.tar.gz --profile $REACTORY_CONFIG
    echo "🛠️ Extracting Reactory data in minikube"
    minikube ssh "sudo mkdir -p /var/reactory && sudo tar -xzf /tmp/reactory-data.tar.gz -C /var/reactory && sudo rm /tmp/reactory-data.tar.gz" --profile $REACTORY_CONFIG --native-ssh
    rm /tmp/reactory-data.tar.gz
  fi
}
