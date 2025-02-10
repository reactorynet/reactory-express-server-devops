#!/bin/bash

cat <<EOF > $TARGET_DIR/terraform.tfvars
reactory_home="${REACTORY_HOME}"
reactory_server_root="${REACTORY_SERVER}"
reactory_server_modules_root="${REACTORY_SERVER}/src/modules"
reactory_mongo_db="${MONGO_DB}"
reactory_mongo_password="${MONGO_PASSWORD}"
reactory_mongo_user="${MONGO_USER}"
reactory_mongo_port=${MONGO_PORT}

reactory_postgres_user="${REACTORY_POSTGRES_USER}"
reactory_postgres_db="${REACTORY_POSTGRES_DB}"
reactory_postgres_password="${REACTORY_POSTGRES_PASSWORD}"
reactory_postgres_host="${REACTORY_POSTGRES_HOST}"
reactory_postgres_port="${REACTORY_POSTGRES_PORT}"

reactory_redis_password="${REACTORY_REDIS_PASSWORD}"
reactory_meilisearch_master_key="${MEILISEARCH_MASTER_KEY}"
reactory_grafana_admin_password="${REACTORY_GRAFANA_PASSWORD}"
EOF