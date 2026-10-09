# ---------------------------------------------------------------------------
# beforerun.sh — sourced by bin/terraform.sh before any terraform command.
#
# Resolves GHCR pull credentials from the gh CLI when they are not already
# supplied, so the private image pull secret can be created without a token
# being written anywhere by hand.
#
# Override by exporting TF_VAR_registry_username / TF_VAR_registry_token (in
# .env.digitalocean or the shell) — this script never overwrites them.
# ---------------------------------------------------------------------------

if command -v gh >/dev/null 2>&1; then
  if [ -z "${TF_VAR_registry_username:-}" ]; then
    TF_VAR_registry_username="$(gh api user --jq .login 2>/dev/null || true)"
    [ -n "$TF_VAR_registry_username" ] && export TF_VAR_registry_username
  fi

  # `gh auth token` returns the logged-in OAuth token, which carries
  # read:packages for GHCR. A classic PAT with read:packages works equally well
  # and is the fallback if the OAuth token is ever rejected by the registry.
  if [ -z "${TF_VAR_registry_token:-}" ]; then
    TF_VAR_registry_token="$(gh auth token 2>/dev/null || true)"
    [ -n "$TF_VAR_registry_token" ] && export TF_VAR_registry_token
  fi
fi

if [ -z "${TF_VAR_registry_token:-}" ]; then
  echo "⚠️  TF_VAR_registry_token is unset and gh could not supply one — the imagePullSecret will be incomplete." >&2
fi

# Point the providers at the pinned kubeconfig unless already overridden.
if [ -z "${TF_VAR_kubeconfig_path:-}" ]; then
  export TF_VAR_kubeconfig_path="${REACTORY_PRIMARY_KUBECONFIG:-$HOME/.kube/reactory-primary.yaml}"
fi
