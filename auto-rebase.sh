#!/bin/bash
set -euo pipefail

# Validate required environment variables
if [ -z "${GIT_USER_NAME:-}" ] || [ -z "${GIT_USER_EMAIL:-}" ]; then
  echo "Error: GIT_USER_NAME and GIT_USER_EMAIL environment variables are required"
  exit 1
fi

if [ -z "${BASE_BRANCH:-}" ] || [ -z "${HEAD_BRANCH:-}" ] || [ -z "${COMMIT_MESSAGE:-}" ]; then
  echo "Error: BASE_BRANCH, HEAD_BRANCH, and COMMIT_MESSAGE environment variables are required"
  exit 1
fi

# Check if signing is enabled
ENABLE_SIGNING="${ENABLE_SIGNING:-false}"
if [ "$ENABLE_SIGNING" = "true" ]; then
  if [ -z "${GPG_PRIVATE_KEY:-}" ]; then
    echo "Error: GPG_PRIVATE_KEY is required when enable-signing is true"
    exit 1
  fi
  echo "GPG signing is enabled"
else
  echo "GPG signing is disabled - using normal commits"
fi

# Configure git user
git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

# Setup GPG if signing is enabled
if [ "$ENABLE_SIGNING" = "true" ]; then
  # Setup GPG environment
  export GPG_TTY=$(tty)
  export GNUPGHOME="$HOME/.gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"

  # Import GPG key
  echo "$GPG_PRIVATE_KEY" | gpg --batch --yes --quiet --import

  # Extract key ID
  KEYID=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2}' | cut -d'/' -f2 | head -n1)
  if [ -z "$KEYID" ]; then
    KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5}' | head -n1)
  fi
  if [ -z "$KEYID" ]; then
    echo "Error: Could not extract GPG key ID"
    exit 1
  fi

  echo "Using GPG key ID: $KEYID"

  # Set trust level
  FINGERPRINT=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10}' | head -n1)
  if [ -n "$FINGERPRINT" ]; then
    echo "$FINGERPRINT:6:" | gpg --batch --import-ownertrust
  fi

  # Configure git for GPG signing
  git config user.signingkey "$KEYID"
  git config commit.gpgsign true
  git config gpg.program gpg

  # Configure GPG for non-interactive use
  cat > "$GNUPGHOME/gpg-agent.conf" << EOF
allow-loopback-pinentry
pinentry-mode loopback
default-cache-ttl 7200
max-cache-ttl 7200
EOF

  cat > "$GNUPGHOME/gpg.conf" << EOF
pinentry-mode loopback
use-agent
batch
no-tty
EOF

  gpg-connect-agent reloadagent /bye || true

  # Test signing method
  SIGNING_METHOD="failed"
  if [ -n "${GPG_PASSPHRASE:-}" ]; then
    if echo "test" | gpg --batch --yes --quiet --armor --detach-sign --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" >/dev/null 2>&1; then
      SIGNING_METHOD="with_passphrase"
      echo "GPG signing method: with passphrase"
    fi
  else
    if echo "test" | gpg --batch --yes --quiet --armor --detach-sign --pinentry-mode loopback --passphrase "" >/dev/null 2>&1; then
      SIGNING_METHOD="no_passphrase"
      echo "GPG signing method: no passphrase"
    fi
  fi

  if [ "$SIGNING_METHOD" = "failed" ]; then
    echo "Error: GPG signing test failed"
    exit 1
  fi
else
  # Disable GPG signing for normal commits
  git config commit.gpgsign false
fi

# Perform rebase
echo "Fetching base branch: $BASE_BRANCH"
git fetch origin "$BASE_BRANCH"

echo "Resetting to base branch..."
git reset --soft "origin/$BASE_BRANCH"

# Create commit (signed or normal based on configuration)
if [ "$ENABLE_SIGNING" = "true" ]; then
  echo "Creating signed commit..."
  if [ "$SIGNING_METHOD" = "with_passphrase" ]; then
    echo "$GPG_PASSPHRASE" | git commit -S -m "$COMMIT_MESSAGE"
  elif [ "$SIGNING_METHOD" = "no_passphrase" ]; then
    git commit -S -m "$COMMIT_MESSAGE"
  fi
else
  echo "Creating normal commit..."
  git commit -m "$COMMIT_MESSAGE"
fi

# Push changes
echo "Pushing changes to $HEAD_BRANCH..."
git push --force-with-lease origin "HEAD:$HEAD_BRANCH"

# Get the commit SHA
COMMIT_SHA=$(git rev-parse HEAD)
echo "commit-sha=$COMMIT_SHA" >> $GITHUB_OUTPUT
echo "success=true" >> $GITHUB_OUTPUT

echo "✅ Auto-rebase completed successfully"
echo "📝 Commit SHA: $COMMIT_SHA"