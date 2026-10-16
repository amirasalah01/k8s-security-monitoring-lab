#!/usr/bin/env bash
# Deletes the whole lab
set -euo pipefail
kind delete cluster --name secmon-lab
echo "Lab removed."
