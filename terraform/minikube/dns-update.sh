REACTORY_CONFIG=${1:-"reactory"}
REACTORY_ENV=${2:-"minikube"}
MINIKUBE_IP=$(minikube ip -p $REACTORY_CONFIG)
MINIKUBE_DOMAIN="$REACTORY_CONFIG.minikube"
HOSTS_FILE=${3:-"/tmp/hosts"}
SYSTEM_HOSTS_FILE=${4:-"/etc/hosts"}

if [ -f $HOSTS_FILE ]; then
  rm $HOSTS_FILE
fi

touch $HOSTS_FILE

grep -v "$MINIKUBE_DOMAIN" $SYSTEM_HOSTS_FILE > $HOSTS_FILE

echo "🛠️ Removed existing entries for $MINIKUBE_DOMAIN"
echo "# $MINIKUBE_DOMAIN - The entries below are automatically created" >> $HOSTS_FILE

for service in app grafana prometheus jaeger meilisearch pwa mongodb postgres redis; do  
  echo "$MINIKUBE_IP $service.$MINIKUBE_DOMAIN" >> $HOSTS_FILE
done

echo "# $MINIKUBE_DOMAIN end " >> $HOSTS_FILE
echo "🛠️ Updating $SYSTEM_HOSTS_FILE file"

cat $HOSTS_FILE | sudo tee $SYSTEM_HOSTS_FILE
rm $HOSTS_FILE