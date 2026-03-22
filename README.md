# Auto Rebase PR Action

A GitHub Action that automatically rebases pull requests with optional GPG signing support.

## About

I created this action to simplify the PR rebase workflow for teams and individual developers. Everyone is welcome to use it freely in their projects. If you encounter any issues or bugs, feel free to open an issue and we can solve it together!

## Features

- 🔄 Automatic PR rebasing onto base branch
- ✍️ Optional GPG commit signing
- 🔒 Support for both signed and normal commits
- 🚀 Zero configuration required - smart defaults for everything
- 📦 Easy to use - just 2 lines of code

## Quick Start

### Minimal Usage (Normal Commits)

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
    ref: ${{ github.event.pull_request.head.ref }}

- uses: 525Kiran/525Kiran-auto-rebase@v1
```

That's it! The action automatically detects PR branches and uses the PR title as commit message.

### Complete Workflow Example

```yaml
name: Auto Rebase PR
on:
  pull_request:
    types: [labeled]

permissions:
  contents: write
  pull-requests: write

jobs:
  rebase:
    if: github.event.label.name == 'auto-rebase'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: ${{ github.event.pull_request.head.ref }}
      
      - uses: 525Kiran/525Kiran-auto-rebase@v1
```

### With GPG Signing

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
    ref: ${{ github.event.pull_request.head.ref }}

- uses: 525Kiran/525Kiran-auto-rebase@v1
  with:
    enable-signing: 'true'
    gpg-private-key: ${{ secrets.GPG_PRIVATE_KEY }}
    gpg-passphrase: ${{ secrets.GPG_PASSPHRASE }}
    git-user-name: ${{ secrets.GIT_USER_NAME }}
    git-user-email: ${{ secrets.GIT_USER_EMAIL }}
```

### Custom Configuration

```yaml
- uses: 525Kiran/525Kiran-auto-rebase@v1
  with:
    git-user-name: 'My Bot'
    git-user-email: 'bot@example.com'
    commit-message: 'Custom commit message'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `github-token` | GitHub token for authentication | No | `${{ github.token }}` |
| `git-user-name` | Git user name for commits | No | `github-actions[bot]` |
| `git-user-email` | Git user email for commits | No | `github-actions[bot]@users.noreply.github.com` |
| `base-branch` | Base branch to rebase onto | No | Auto-detected from PR |
| `head-branch` | Head branch to rebase | No | Auto-detected from PR |
| `commit-message` | Commit message | No | Uses PR title |
| `enable-signing` | Enable GPG signing (true/false) | No | `false` |
| `gpg-private-key` | GPG private key for signing | **Only when `enable-signing: 'true'`** | - |
| `gpg-passphrase` | GPG key passphrase | Only if your GPG key has a passphrase | - |

**Note:** `gpg-private-key` and `gpg-passphrase` are only required when you set `enable-signing: 'true'`. For normal commits without signing, you don't need to provide these inputs.

## Outputs

| Output | Description |
|--------|-------------|
| `success` | Whether the rebase was successful |
| `commit-sha` | SHA of the new commit after rebase |

## Setup Guide

### Basic Setup (Normal Commits)

1. Create `.github/workflows/auto-rebase.yml` in your repository
2. Copy the complete workflow example above
3. Add the `auto-rebase` label to your repository (Settings → Labels)
4. Label any PR with `auto-rebase` to trigger automatic rebasing

### GPG Signing Setup

**Step 1: Generate GPG Key**
```bash
gpg --full-generate-key
```
Follow the prompts to create your key.

**Step 2: Export Private Key**
```bash
# List your keys to get the KEY_ID
gpg --list-secret-keys --keyid-format=long

# Export the private key
gpg --armor --export-secret-keys YOUR_KEY_ID > private.key
```

**Step 3: Add Secrets to Repository**
Go to your repository → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:
- `GPG_PRIVATE_KEY` - Paste the entire content of `private.key`
- `GPG_PASSPHRASE` - Your GPG key passphrase (if you set one)
- `GIT_USER_NAME` - Your name (e.g., "John Doe")
- `GIT_USER_EMAIL` - Email used in GPG key (must match exactly)

**Step 4: Add Public Key to GitHub**
```bash
# Export public key
gpg --armor --export YOUR_KEY_ID

# Copy the output and add it to:
# GitHub → Settings → SSH and GPG keys → New GPG key
```

**Step 5: Update Workflow**
Set `enable-signing: 'true'` in your workflow and add the GPG inputs.

## How It Works

1. Fetches the base branch from origin
2. Performs a soft reset to the base branch (preserves all changes)
3. Creates a new commit with all PR changes
4. Optionally signs the commit with GPG
5. Force pushes to the head branch with `--force-with-lease` for safety

## Troubleshooting

### Action doesn't trigger
- Verify workflow file is in `.github/workflows/` directory
- Check label name matches exactly (case-sensitive)
- Ensure workflow is on the default branch
- Verify Actions are enabled in repository settings

### GPG signing fails
- Verify email in `GIT_USER_EMAIL` matches GPG key email exactly
- Check GPG key hasn't expired: `gpg --list-keys`
- Ensure private key includes BEGIN and END markers
- If key has no passphrase, omit the `gpg-passphrase` input

### Commits not showing as "Verified"
- Add GPG public key to your GitHub account
- Verify email matches your GitHub account email
- Check key is not expired or revoked

### Push fails with "protected branch"
- Update branch protection rules to allow force pushes from GitHub Actions
- Or add GitHub Actions bot to allowed users in branch protection

### Permission denied errors
- Add workflow permissions:
  ```yaml
  permissions:
    contents: write
    pull-requests: write
  ```

## Contributing & Support

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/525Kiran/525Kiran-auto-rebase/issues).

If you find this action helpful, give it a ⭐️ on GitHub!
