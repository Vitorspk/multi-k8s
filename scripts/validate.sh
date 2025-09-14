#!/bin/bash

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_info "🔍 Multi-K8s Project Validation"
echo ""

ERRORS=0

# Check required tools
echo "Prerequisites:"
command -v gcloud &>/dev/null && echo "✅ gcloud" || { echo "❌ gcloud missing"; ((ERRORS++)); }
command -v kubectl &>/dev/null && echo "✅ kubectl" || { echo "❌ kubectl missing"; ((ERRORS++)); }
command -v docker &>/dev/null && echo "✅ docker" || { echo "❌ docker missing"; ((ERRORS++)); }

echo ""

# Check critical files
echo "Files:"
[[ -f "k8s/server-config.yaml" ]] && echo "✅ k8s configs" || { echo "❌ k8s configs missing"; ((ERRORS++)); }
[[ -f "scripts/manage-secrets.sh" ]] && echo "✅ secret manager scripts" || { echo "❌ secret manager scripts missing"; ((ERRORS++)); }
[[ -f ".github/workflows/deploy.yml" ]] && echo "✅ github workflows" || { echo "❌ github workflows missing"; ((ERRORS++)); }

echo ""

# Check security
echo "Security:"
[[ ! -f "service-account.json" ]] && echo "✅ no service-account.json" || { echo "❌ service-account.json found (SECURITY RISK)"; ((ERRORS++)); }
grep -q "service-account.json" .gitignore 2>/dev/null && echo "✅ service-account.json in .gitignore" || { echo "❌ service-account.json not in .gitignore"; ((ERRORS++)); }

echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo "✅ Validation passed!"
    exit 0
else
    echo "❌ $ERRORS errors found"
    exit 1
fi