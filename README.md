# GitHub Actions Runner for OpenShift

A generic, reusable container image that runs a GitHub Actions self-hosted runner with the OpenShift `oc` CLI pre-installed.

## What's inside

- GitHub Actions Runner v2.322.0
- OpenShift `oc` CLI v4.14
- Runs as non-root (UID 1001), compatible with OpenShift restricted SCC
- Ephemeral mode: each job gets a clean runner, auto-deregisters after completion
- Graceful shutdown: catches SIGTERM and deregisters from GitHub before stopping

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_PAT` | yes | — | Classic PAT with `repo` + `workflow` scopes |
| `GITHUB_OWNER` | yes | — | GitHub org or user (e.g. `Minca-AI`) |
| `GITHUB_REPO` | yes | — | Repository name (e.g. `Minca-AI-tool-GS`) |
| `OC_TOKEN` | no | — | OpenShift API token for `oc login` |
| `OC_SERVER` | no | — | OpenShift API server URL |
| `RUNNER_NAME` | no | hostname | Runner name shown in GitHub |
| `RUNNER_LABELS` | no | `openshift,self-hosted,linux` | Comma-separated labels |
| `RUNNER_GROUP` | no | `Default` | Runner group |

## Build

The image is automatically built and pushed to GitHub Container Registry on every push to `main` via the included workflow (`.github/workflows/build-and-push.yml`).

To build manually:

```bash
docker build -t ghcr.io/your-org/github-runner-openshift:latest .
docker push ghcr.io/your-org/github-runner-openshift:latest
```

## Run locally (for testing)

```bash
cp .env.example .env
# Fill in your values
docker run --env-file .env ghcr.io/your-org/github-runner-openshift:latest
```

## Deploy on OpenShift

Create a deployment using the public image and set the environment variables:

```bash
oc new-app --name=github-runner \
  --docker-image=ghcr.io/your-org/github-runner-openshift:latest \
  -n gds-sa-dev

oc set env deployment/github-runner \
  GITHUB_PAT=ghp_xxx \
  GITHUB_OWNER=Minca-AI \
  GITHUB_REPO=Minca-AI-tool-GS \
  OC_TOKEN=sha256~xxx \
  OC_SERVER=https://api.your-cluster.com:443 \
  -n gds-sa-dev
```

Or use a secret for sensitive values:

```bash
oc create secret generic runner-env \
  --from-literal=GITHUB_PAT=ghp_xxx \
  --from-literal=OC_TOKEN=sha256~xxx \
  -n gds-sa-dev

oc set env deployment/github-runner --from=secret/runner-env -n gds-sa-dev
```

## Use in a workflow

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, openshift]
    steps:
      - uses: actions/checkout@v4
      - run: oc whoami
      - run: oc get pods -n gds-sa-dev
```
