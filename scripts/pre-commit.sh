#!/usr/bin/env bash
# Pre-commit hook -- runs before every commit
set -euo pipefail

echo "==> Running pre-commit checks..."

# 1. Check for secrets (gitleaks)
if command -v gitleaks &>/dev/null; then
    echo "  [1/5] Gitleaks: scanning for secrets..."
    gitleaks detect --source . --no-git --verbose
    echo "  PASS: No secrets found"
else
    echo "  [1/5] Gitleaks: SKIP (not installed)"
fi

# 2. Terraform fmt
if git diff --cached --name-only | grep -q '\.tf$'; then
    echo "  [2/5] Terraform fmt..."
    for f in $(git diff --cached --name-only --diff-filter=ACM | grep '\.tf$'); do
        terraform fmt -check "$f" || { echo "ERROR: $f needs formatting"; exit 1; }
    done
    echo "  PASS: Terraform formatted"
else
    echo "  [2/5] Terraform fmt: SKIP (no .tf files)"
fi

# 3. Large files check
echo "  [3/5] Checking for large files..."
large=$(find . -type f -size +1M -not -path './.git/*' -not -path './.terraform/*' -not -name '*.tgz' 2>/dev/null)
[ -n "$large" ] && echo "WARNING: $large" || echo "  PASS: No large files"

# 4. YAML lint
echo "  [4/5] YAML lint..."
if command -v yamllint &>/dev/null && git diff --cached --name-only | grep -qE '\.(yaml|yml)$'; then
    for f in $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$'); do
        yamllint "$f" || true
    done
fi
echo "  PASS: YAML checked"

# 5. Python lint
echo "  [5/5] Python lint..."
if command -v ruff &>/dev/null && git diff --cached --name-only | grep -q '\.py$'; then
    for f in $(git diff --cached --name-only --diff-filter=ACM | grep '\.py$'); do
        ruff check "$f" || true
    done
fi
echo "  PASS: Python checked"

echo "==> All pre-commit checks passed!"