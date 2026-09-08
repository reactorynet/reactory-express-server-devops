#!/bin/bash
# Dynamically extract GHCR pull credentials from gh CLI for Kubernetes imagePullSecrets
if command -v gh >/dev/null 2>&1; then
  GH_TOKEN=$(gh auth token 2>/dev/null || echo "")
  if [ -n "$GH_TOKEN" ]; then
    export TF_VAR_registry_auth="{server=\"ghcr.io\",username=\"wweber\",password=\"$GH_TOKEN\"}"
  fi
fi
