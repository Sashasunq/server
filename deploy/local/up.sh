#!/usr/bin/env bash
# Brings up a local cluster that follows the registry on its own: minikube, the
# reconciler as a CronJob, and nothing else needed.
#
#   VAULT_ADDR=https://vault.ffmpeglab.com \
#   VAULT_USERNAME=... VAULT_PASSWORD=... deploy/local/up.sh
#
# Credentials come from the environment so they stay out of this file and out of
# shell history if you keep them in a .env.

set -euo pipefail

: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_USERNAME:?set VAULT_USERNAME}"
: "${VAULT_PASSWORD:?set VAULT_PASSWORD}"

root=$(cd "$(dirname "$0")/../.." && pwd)

# Small on purpose: the whole point is that this fits on a laptop. Docker itself
# needs about 4 GB for this to hold three tenants.
if ! minikube status >/dev/null 2>&1; then
  minikube start --memory=3000mb --cpus=2 --driver=docker
fi

# Built straight into the cluster's own daemon, so no registry is involved and
# nothing has to be pushed anywhere.
eval "$(minikube docker-env)"
docker build -q -f "$root/deploy/reconciler/Dockerfile" \
  -t ffmpeglab-reconciler:local "$root/deploy" >/dev/null

kubectl apply -f "$root/deploy/reconciler/manifests.yaml"

kubectl create secret generic vault-login -n ffmpeglab-reconciler \
  --from-literal=VAULT_ADDR="$VAULT_ADDR" \
  --from-literal=VAULT_USERNAME="$VAULT_USERNAME" \
  --from-literal=VAULT_PASSWORD="$VAULT_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Without this the first reconcile waits for the schedule.
kubectl delete job -n ffmpeglab-reconciler first --ignore-not-found >/dev/null
kubectl create job -n ffmpeglab-reconciler first --from=cronjob/reconciler

echo
echo "Reconciling now. Follow it with:"
echo "  kubectl logs -n ffmpeglab-reconciler -l job-name=first -f"
