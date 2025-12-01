#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-keycloak}
: "${DEMO_URL:?Set DEMO_URL to the Keycloak demo hostname (without protocol)}"

kubectl -n "$NAMESPACE" wait --for=condition=ready pod -l app=keycloak --timeout=120s
curl -k "https://${DEMO_URL}/health/ready"
