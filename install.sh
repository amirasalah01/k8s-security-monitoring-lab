#!/usr/bin/env bash
# One-command install of the lab (run from the repo root, in WSL2 / Linux / macOS)
set -euo pipefail

echo "==> 1/6 Creating kind cluster"
if ! kind get clusters | grep -q '^secmon-lab$'; then
  kind create cluster --config cluster/kind-config.yaml
fi

echo "==> 2/6 Adding Helm repositories"
helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

echo "==> 3/6 Installing Loki (security event store)"
helm upgrade --install loki grafana/loki \
  -n monitoring --create-namespace -f helm/loki-values.yaml --wait --timeout 10m

echo "==> 4/6 Installing Prometheus + Grafana + SOC dashboard"
kubectl create configmap soc-dashboard -n monitoring \
  --from-file=soc-dashboard.json=grafana/soc-dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap soc-dashboard -n monitoring grafana_dashboard=1 --overwrite
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f helm/kube-prometheus-values.yaml --wait --timeout 15m

echo "==> 5/6 Deploying n8n (alert automation)"
kubectl apply -f k8s/n8n.yaml
kubectl rollout status deployment/n8n -n automation --timeout=5m

echo "==> 6/6 Installing Falco + Falcosidekick with custom rules"
helm upgrade --install falco falcosecurity/falco \
  -n falco --create-namespace -f helm/falco-values.yaml \
  --set-file 'customRules.custom-rules\.yaml'=falco-rules/custom-rules.yaml \
  --wait --timeout 10m

kubectl apply -f k8s/vulnerable-app.yaml

cat <<EOF

Lab ready:
  Grafana           http://localhost:3000   (admin / admin) -> dashboard "SOC - Kubernetes Runtime Security"
  n8n               http://localhost:5678   -> import n8n/falco-slack-workflow.json, set your Slack webhook, activate
  Falcosidekick UI  http://localhost:2802   (admin / admin)

Next: ./scripts/simulate-attacks.sh
EOF
