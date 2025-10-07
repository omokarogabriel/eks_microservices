# 🗑️ Git Cleanup Guide - Removing Large Files

## 🚨 Problem: GitHub File Size Limits

When pushing Terraform projects to GitHub, you may encounter:
- **File size limit**: Individual files > 100MB rejected
- **Repository size limit**: Total size > 1GB causes issues
- **Common culprits**: Terraform provider binaries, state files

## 🛠️ Solution: git-filter-repo

### 1. Install git-filter-repo
```bash
pip install git-filter-repo
```

### 2. Remove Specific Directories
```bash
# Remove .terraform directory from specific environment
git filter-repo --path environments/dev/.terraform --invert-paths

# Remove from all environments
git filter-repo --path .terraform --invert-paths
```

### 3. Remove State Files
```bash
# Remove all Terraform state files
git filter-repo --path terraform.tfstate --invert-paths
git filter-repo --path terraform.tfstate.backup --invert-paths

# Remove with pattern matching
git filter-repo --path-glob '*.tfstate*' --invert-paths
```

### 4. Force Push Changes
```bash
# Push rewritten history
git push origin main --force

# For specific branch
git push origin dev --force
```

## 🎯 Common Scenarios

### Scenario 1: Single Environment Cleanup
```bash
# Remove dev environment .terraform directory
git filter-repo --path environments/dev/.terraform --invert-paths
git push origin dev --force
```

### Scenario 2: All Environments Cleanup
```bash
# Remove all .terraform directories
git filter-repo --path-glob '*/.terraform' --invert-paths
git filter-repo --path-glob '*.tfstate*' --invert-paths
git push origin main --force
```

### Scenario 3: Specific File Types
```bash
# Remove all large binary files
git filter-repo --path-glob '*.zip' --invert-paths
git filter-repo --path-glob '*.tar.gz' --invert-paths
git filter-repo --path-glob 'terraform-provider-*' --invert-paths
```

## 🛡️ Prevention with .gitignore

Create comprehensive `.gitignore`:
```gitignore
# Terraform files
**/.terraform/
**/.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json

# Environment specific
environments/**/.terraform/
environments/**/*.tfstate*
environments/**/terraform.tfvars

# Backend setup
backend-setup/.terraform/
backend-setup/*.tfstate*
```

## ⚠️ Important Notes

### Before Running git-filter-repo:
1. **Backup your repository**: `git clone --mirror`
2. **Coordinate with team**: Notify all contributors
3. **Fresh clone required**: After filter-repo, everyone needs fresh clone

### After Running git-filter-repo:
1. **Force push required**: History has been rewritten
2. **Team coordination**: All team members need to re-clone
3. **CI/CD updates**: May need to update deployment keys

## 🔍 Verification Commands

### Check Repository Size
```bash
# Check current repository size
du -sh .git

# List largest files
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  sed -n 's/^blob //p' | \
  sort --numeric-sort --key=2 | \
  tail -10
```

### Verify Cleanup
```bash
# Check if files are gone
find . -name ".terraform" -type d
find . -name "*.tfstate*"

# Check Git status
git status
git log --oneline -10
```

## 🚀 Alternative: BFG Repo-Cleaner

If git-filter-repo doesn't work:
```bash
# Install BFG
brew install bfg  # macOS
# or download from: https://rtyley.github.io/bfg-repo-cleaner/

# Remove large files
bfg --delete-folders .terraform
bfg --delete-files "*.tfstate*"

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

## 📊 File Size Limits

| Platform | Individual File | Repository |
|----------|----------------|------------|
| GitHub | 100MB (hard limit) | 1GB (soft limit) |
| GitLab | 100MB (default) | Configurable |
| Bitbucket | 100MB (default) | 2GB (soft limit) |

## 🔗 Related Commands

```bash
# Check large files before commit
git ls-files | xargs ls -la | sort -k5 -rn | head -10

# Remove from staging
git rm --cached large-file.zip

# Amend last commit (if not pushed)
git commit --amend

# Reset to previous commit
git reset --hard HEAD~1
```

## 📞 Troubleshooting

### "fatal: not a git repository"
```bash
# Ensure you're in Git repository root
cd /path/to/your/repo
git status
```

### "Cannot force push to protected branch"
```bash
# Temporarily disable branch protection
# Or create new branch and merge
git checkout -b cleanup-large-files
git filter-repo --path .terraform --invert-paths
git push origin cleanup-large-files
```

### "git-filter-repo not found"
```bash
# Install with pip
pip install git-filter-repo

# Or with conda
conda install -c conda-forge git-filter-repo

# Or download directly
curl -O https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo
chmod +x git-filter-repo
```

This guide ensures your Terraform projects stay within Git hosting limits while maintaining clean repository history.