# Production promotion process

This document describes the gate between beta qualification and production.

## 1. Checking the release branch against master

For each beta project, the workflow checks whether the release branch is structurally consistent with master:

```bash
git fetch origin
git merge-base --is-ancestor origin/master origin/release/2.8
```

If the check fails, promotion must be blocked.

This indicates that `master` has evolved since the release branch was created, often due to a hotfix.

## 2. Corrective action

When the check fails, the branch must be merged with master before any production promotion can be considered:

```bash
git checkout release/2.8
git pull
git merge origin/master
```

Then resolve conflicts, push the update, and rerun qualification.

## 3. Merge Request preparation

A production merge is done using a GitLab Merge Request to `master`, ideally from the release branch to `master`.

This keeps the protected branch stable and leaves an auditable trail.

## 4. Tagging after merge

Once the Merge Request is merged:

```bash
git checkout master
git pull
git tag -a v2.8.3 -m "Release v2.8.3"
git push origin v2.8.3
```

This ensures that production tags reflect exactly what is on `master`.

## 5. Propagation after production

After a hotfix or production release, the fix must be propagated back to:

- `release/*`
- `dev`

This prevents the same fix from being lost in future releases.

## 6. Hotfix rule

Hotfixes always begin from `master` and are then merged back to the broader release and integration lines.

This is the critical separation between a hotfix and a normal release branch work item.
