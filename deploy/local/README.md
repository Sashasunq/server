# local

A laptop cluster that follows the Vault registry without GitHub, a state bucket,
or anything else outside it.

```bash
VAULT_ADDR=https://vault.ffmpeglab.com \
VAULT_USERNAME=<user> VAULT_PASSWORD=<password> \
deploy/local/up.sh
```

That starts minikube if it is not running, builds the reconciler into the
cluster's own Docker daemon, installs the CronJob and runs it once. From then on
it reconciles every two minutes: switch a tenant on in the platform and it
appears here, switch it off and it goes.

What it looks like when it is working:

```bash
kubectl get pods -A -l app.kubernetes.io/name=ffmpeglab
kubectl get jobs -n ffmpeglab-reconciler
```

## What differs from a real cluster

The secrets operator is not part of this. It authenticates as a pod of its
cluster and Vault verifies that against keys it can reach — which rules out a
minikube behind a home router unless Vault gains an `appRole` or a JWT mount
carrying this cluster's key. Terraform writes the Secrets instead, which is what
it does by default.

The file runner is off: it calls `config.s3.endpoint.search(...)` in its
constructor, so with no storage keys in the tenant record it exits during
startup.

Both runners share one `ReadWriteOnce` volume rather than the `ReadWriteMany`
one a real cluster needs, because a single-node cluster will attach it to
several pods — they all land on the same node.

## Tearing it down

```bash
minikube delete
```

Nothing outside the cluster is touched. The registry is read-only to this
setup — the role it logs in with cannot write — so a local cluster cannot
disturb a real one.
