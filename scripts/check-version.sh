#!/bin/bash
# Check for newer versions of tools

set -e

echo "Checking tool versions against latest releases..."
echo ""

check_github_release() {
    local repo=$1
    local current=$2
    local latest=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name | sed 's/^v//')

    if [ "$current" = "$latest" ]; then
        echo "✅ $repo: $current (latest)"
    else
        echo "⚠️  $repo: $current → $latest (update available)"
    fi
}

echo "GitHub Releases:"
check_github_release "hashicorp/terraform" "1.13.4"
check_github_release "terraform-linters/tflint" "0.59.1"
check_github_release "aquasecurity/tfsec" "1.28.14"
check_github_release "aquasecurity/trivy" "0.66.0"
check_github_release "terraform-docs/terraform-docs" "0.20.0"
check_github_release "gitleaks/gitleaks" "8.21.2"

echo ""
echo "PyPI Packages (always install latest):"
echo "  checkov: $(pip3 show checkov 2>/dev/null | grep Version | awk '{print $2}' || echo 'not installed')"
echo "  pre-commit: $(pip3 show pre-commit 2>/dev/null | grep Version | awk '{print $2}' || echo 'not installed')"
echo ""
echo "To update Dockerfile, edit the ENV variables at the top."
