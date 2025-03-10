
# Update the networking configuration for the profile
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/express_server/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/mongodb/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/postgres/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/grafana/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/prometheus/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/jaeger/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/pwa_client/istio.yaml
kubectl apply -f $REACTORY_SERVER/config/$REACTORY_CONFIG/terraform/minikube/modules/meilisearch/istio.yaml
