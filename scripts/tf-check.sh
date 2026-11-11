#!/usr/bin/env bash
# Plan-only check of dev and prod without an AWS account.
# A temporary backend_override.tf switches the S3 backend to a local one.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=ap-south-1

terraform -chdir="$ROOT/infra" fmt -recursive -check
echo "fmt: OK"

for e in dev prod; do
  D="$ROOT/infra/envs/$e"
  echo "=== $e ==="
  printf 'terraform {\n  backend "local" {}\n}\n' > "$D/backend_override.tf"
  terraform -chdir="$D" init -reconfigure -input=false -no-color > /dev/null
  terraform -chdir="$D" validate -no-color
  if ! OUT=$(terraform -chdir="$D" plan -refresh=false -input=false -no-color -var-file="$e.tfvars" 2>&1); then
    echo "$OUT"
    rm -f "$D/backend_override.tf"
    exit 1
  fi
  echo "$OUT" | grep -E "^Plan:" || true
  rm -f "$D/backend_override.tf"
  rm -rf "$D/.terraform" "$D"/terraform.tfstate*
done
echo "All checks passed"
