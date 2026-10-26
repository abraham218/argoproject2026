# ArgoCD + GitOps Practice Project

A minimal, from-scratch GitOps setup: ArgoCD watches this Git repo and keeps
an nginx demo app in sync across two environments (`dev`, `prod`) on your
kind cluster.

## What's in here

```
argocd-practice-gitops/
├── apps/
│   └── nginx-demo/
│       ├── base/                   # shared manifests
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── configmap.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/                # dev-specific patches (1 replica)
│           └── prod/               # prod-specific patches (3 replicas)
├── argocd/
│   ├── applications/               # ArgoCD Application CRs (what to sync, and how)
│   │   ├── nginx-demo-dev.yaml
│   │   └── nginx-demo-prod.yaml
│   └── install/
│       └── install-argocd.sh       # installs ArgoCD itself on your cluster
└── README.md
```

This uses plain **Kustomize** (base + overlays) rather than Helm or an
App-of-Apps pattern — the goal is to see the core GitOps loop clearly
before adding more structure.

## How the GitOps loop works here

1. You edit a manifest (or overlay patch) and `git push`.
2. ArgoCD, which is polling this repo, notices the diff between Git and
   the live cluster state.
3. For `dev`, `syncPolicy.automated` is on — ArgoCD applies the change
   automatically (and reverts any manual `kubectl edit` drift, because
   `selfHeal: true`).
4. For `prod`, sync is manual — you promote changes by clicking "Sync" in
   the UI or running `argocd app sync nginx-demo-prod`, simulating a
   controlled release gate.

## Step-by-step setup

### 1. Install ArgoCD on your kind cluster

```bash
cd argocd-practice-gitops
./argocd/install/install-argocd.sh
```

This installs ArgoCD into the `argocd` namespace and prints the next steps
(port-forward + initial admin password).

### 2. Log into the ArgoCD UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Open **https://localhost:8080**, log in as `admin` with that password.
(Browser will warn about the self-signed cert — that's expected locally.)

### 3. Push this repo to your own GitHub

```bash
git init
git add .
git commit -m "Initial ArgoCD GitOps practice project"
git branch -M main
git remote add origin https://github.com/<your-username>/argocd-practice-gitops.git
git push -u origin main
```

### 4. Point the Applications at your repo

Edit the `repoURL` field in both:
- `argocd/applications/nginx-demo-dev.yaml`
- `argocd/applications/nginx-demo-prod.yaml`

to your actual GitHub URL, then commit/push that change too.

### 5. Register the Applications with ArgoCD

```bash
kubectl apply -f argocd/applications/nginx-demo-dev.yaml
kubectl apply -f argocd/applications/nginx-demo-prod.yaml
```

Dev will sync automatically within seconds. Prod will show as
"OutOfSync" until you manually sync it (in the UI, or `argocd app sync
nginx-demo-prod`).

### 6. See it running

```bash
kubectl -n nginx-demo-dev port-forward svc/nginx-demo 8081:80
```

Open http://localhost:8081 — you should see the blue "DEV" page.
Do the same for prod on a different local port once you sync it, and
you'll see the red "PROD" page with 3 replicas instead of 1.

## Things to try next (the actual learning part)

- **Make a change and watch it sync**: edit `overlays/dev/configmap-patch.yaml`
  (change the text or color), push, and watch ArgoCD auto-sync within its
  poll interval (or hit "Refresh" in the UI to force it immediately).
- **Test self-heal**: run `kubectl -n nginx-demo-dev scale deploy/nginx-demo --replicas=5`
  manually, then watch ArgoCD silently revert it back to 1 — this is the
  core GitOps guarantee ("Git is the single source of truth").
- **Practice a rollback**: `git revert` a commit and push — ArgoCD will sync
  the cluster back to the previous state automatically (dev) or on your
  next manual sync (prod).
- **Break the sync on purpose**: introduce a YAML typo, push, and see how
  ArgoCD surfaces the error in the UI instead of silently failing.
- **Graduate to App-of-Apps**: once this feels natural, we can add a
  top-level `Application` that itself manages the dev/prod `Application`
  objects, which is the pattern used for multi-app, multi-team setups.
