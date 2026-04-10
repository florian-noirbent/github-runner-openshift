#!/bin/bash
set -euo pipefail

# -------------------------------------------------------
# Generic GitHub Actions Self-Hosted Runner
# All config comes from environment variables.
# -------------------------------------------------------

# Required
: "${GITHUB_PAT:?GITHUB_PAT is required}"
: "${GITHUB_OWNER:?GITHUB_OWNER is required}"
: "${GITHUB_REPO:?GITHUB_REPO is required}"

# Optional — OpenShift auth (skip if not set)
OC_TOKEN="${OC_TOKEN:-}"
OC_SERVER="${OC_SERVER:-}"

# Optional — runner config
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-openshift,self-hosted,linux}"
RUNNER_GROUP="${RUNNER_GROUP:-Default}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/home/runner/_work}"

REPO_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}"
API_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runners"

# -------------------------------------------------------
fetch_registration_token() {
    echo "Fetching runner registration token..."
    REG_TOKEN=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_PAT}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${API_URL}/registration-token" \
        | jq -r '.token')

    if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
        echo "ERROR: Failed to fetch registration token. Check GITHUB_PAT permissions."
        exit 1
    fi
    echo "Registration token obtained."
}

# -------------------------------------------------------
cleanup() {
    echo ""
    echo "Caught signal — deregistering runner..."
    REMOVE_TOKEN=$(curl -s -X POST \
        -H "Authorization: token ${GITHUB_PAT}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${API_URL}/remove-token" \
        | jq -r '.token')

    if [ -n "$REMOVE_TOKEN" ] && [ "$REMOVE_TOKEN" != "null" ]; then
        ./config.sh remove --unattended --token "$REMOVE_TOKEN" || true
        echo "Runner deregistered."
    else
        echo "WARNING: Could not fetch removal token."
    fi
}

# -------------------------------------------------------
setup_oc() {
    if [ -n "$OC_TOKEN" ] && [ -n "$OC_SERVER" ]; then
        echo "Logging into OpenShift at ${OC_SERVER}..."
        oc login --token="$OC_TOKEN" --server="$OC_SERVER" --insecure-skip-tls-verify=true
        echo "oc CLI ready."
    else
        echo "OC_TOKEN/OC_SERVER not set — skipping oc login."
    fi
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
trap cleanup SIGTERM SIGINT SIGQUIT

setup_oc
fetch_registration_token

echo "Configuring runner: ${RUNNER_NAME}"
./config.sh \
    --url "$REPO_URL" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "$RUNNER_WORKDIR" \
    --unattended \
    --ephemeral \
    --replace

unset REG_TOKEN

echo "Starting runner..."
./run.sh &
wait $!
