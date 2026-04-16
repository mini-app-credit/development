# Deployment Setup

Copy this directory to `deployment/` and fill in values:

```bash
cp -r deployment.example/ deployment/
# Edit deployment/deployment.env — domains, project name
# Edit deployment/sensitive.env — passwords, secrets, OAuth keys
```

## File Structure

| File | Purpose | Commit? |
|------|---------|---------|
| `deployment.env` | Environment-specific config (domains, project name) | No |
| `sensitive.env` | Secrets, passwords, API keys | Never |

## Environment File Load Order

```
vendor.env              → Static defaults (versioned)
deployment/deployment.env → Environment-specific (git-ignored)
deployment/sensitive.env  → Secrets (git-ignored)
derived.env             → Computed from above (versioned)
```

Later files override earlier ones.
