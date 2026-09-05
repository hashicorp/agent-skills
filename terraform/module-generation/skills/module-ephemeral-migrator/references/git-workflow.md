# Git Workflow — Major Version PR

## Detect Version

Run before generating any files — `NEXT_MAJOR` is needed for upgrade doc filenames.

```bash
CURRENT_VERSION=$(git tag --list 'v*.*.*' --sort=-v:refname | head -n 1)

if [ -z "$CURRENT_VERSION" ]; then
  git fetch --tags
  CURRENT_VERSION=$(git tag --list 'v*.*.*' --sort=-v:refname | head -n 1)
fi

if [ -z "$CURRENT_VERSION" ]; then
  CURRENT_VERSION="v1.0.0"
fi

MAJOR=$(echo $CURRENT_VERSION | sed 's/v//' | cut -d. -f1)
NEXT_MAJOR="v$((MAJOR + 1)).0.0"

echo "Current: $CURRENT_VERSION → Next major: $NEXT_MAJOR"
```

**Example with tag v1.1.1:** `NEXT_MAJOR=v2.0.0`

---

## Files Changed

- `main.tf` — `removed` block, `ephemeral` resource, write-only consumers
- `variables.tf` — `<secret>_data` ephemeral variables, `secret_version`
- `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` — upgrade guide (REQUIRED)
- `docs/skills/tf-ephemeral-upgrade-<module>.md` — upgrade assistant (REQUIRED)
- `README.md` — add breaking change notice, major version bump, and link to `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` in the changelog or migration section

---

## Commit Message

```
feat!: remove secrets from state

BREAKING CHANGE: Legacy secret-generating resources replaced with ephemeral resources.
Existing users must perform a one-time manual migration step before applying.
See docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md for instructions.

- Replace resource blocks with removed + ephemeral
- Add ephemeral input variables for one-time legacy migration
- Update consumers to write-only attributes with conditional
- Add docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md
- Add docs/skills/tf-ephemeral-upgrade-<module>.md

Target version: ${NEXT_MAJOR}
```

---

## PR Description

Write to `docs/pr_description.md` (substitute `${NEXT_MAJOR}` and `${CURRENT_VERSION}` with actual values before writing). Discard file after PR creation.

```markdown
## Description

Removes secrets from Terraform state.

## Version

**MAJOR VERSION BUMP** (${CURRENT_VERSION} → ${NEXT_MAJOR})

⚠️ **BREAKING CHANGE**: Existing users must perform a one-time migration step.

## Impact

### New Deployments
No changes required. Secrets are ephemeral and never written to state.

### Existing Deployments
One-time manual step required on first apply:
1. Extract secret from state into env var
2. Write to HCP Terraform workspace as sensitive variable
3. Apply upgrade — secret preserved, removed from state

Full instructions: `docs/skills/tf-ephemeral-upgrade-<module>.md`

## Changes

### `variables.tf`
- `<secret>_data` (string, ephemeral, sensitive, default: null) — one-time migration input
- `secret_version` (number, default: 1) — increment to re-write write-only secret

### Resource Changes
- `removed { lifecycle { destroy = false } }` replaces legacy resource
- `ephemeral "<type>" "this"` added
- Consumer resources updated to `_wo` write-only attributes with conditional

## Documentation
- `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` — upgrade guide
- `docs/skills/tf-ephemeral-upgrade-<module>.md` — step-by-step upgrade assistant
```

---

## Git Commands

```bash
git checkout -b feat/ephemeral-migration

# Verify required files exist
test -f docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md || echo "ERROR: Upgrade guide not created!"
test -f docs/skills/tf-ephemeral-upgrade-*.md || echo "ERROR: Upgrade skill not created!"

git add main.tf variables.tf docs/ README.md examples/
git commit -m "feat!: remove secrets from state

BREAKING CHANGE: Legacy secret-generating resources replaced with ephemeral resources.
Existing users must perform a one-time manual migration step before applying.
See docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md for instructions.

Target version: ${NEXT_MAJOR}"

git push -u origin feat/ephemeral-migration

gh pr create \
  --title "feat!: remove secrets from state (${NEXT_MAJOR} - MAJOR)" \
  --body-file docs/pr_description.md \
  --label "breaking-change" \
  --label "major-version" \
  --base main

PR_URL=$(gh pr view --json url -q .url)
echo "PR: $PR_URL"
```

---

## Final Output to User

```
✅ Migration complete!

Files created:
- variables.tf — ephemeral input variables
- main.tf — removed block + ephemeral resource + write-only consumers
- docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md ⭐
- docs/skills/tf-ephemeral-upgrade-<module>.md ⭐
- README.md — updated

PR created: $PR_URL

Next steps for maintainers:
1. Review and merge PR
2. Tag: git tag ${NEXT_MAJOR} && git push origin ${NEXT_MAJOR}

Existing users must follow docs/skills/tf-ephemeral-upgrade-<module>.md
before upgrading — one-time step to preserve secret values.
```

---

## Complete Reference

- Blog post: https://dev.to/drewmullen/fully-migrate-secrets-out-of-terraform-module-state-without-breaking-existing-users-1jc5
- Policy library: https://github.com/drewmullen/policy-library-ephemerality
- Ephemerality data: https://raw.githubusercontent.com/drewmullen/policy-library-ephemerality/refs/heads/main/data/ephemerality.json
