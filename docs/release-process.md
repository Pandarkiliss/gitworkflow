# Release process

This document describes how application release branches are created, qualified, and promoted.

## 1. Mandatory upstream check

Before a release is created, the repository must guarantee that `master` is already contained in `dev`.

```bash
git fetch origin
git merge-base --is-ancestor origin/master origin/dev
```

If this check fails, do not create the release branch. The correct action is to merge `master` into `dev` first, then continue.

## 2. Create a release branch

```bash
git checkout -b release/2.8 origin/dev
git push -u origin release/2.8
```

The release branch name is based on the application version family, for example `release/2.8`.

## 3. Release qualification

The release branch is then used for QA, validation, and fix branches:

```bash
git checkout -b fix/issue-456 release/2.8
```

Fixes are rebased on the release branch and merged back to it.

## 4. Alpha to beta transition

A beta is created from a valid release branch while preserving the GitFlow constraints. The release branch is compared against the last beta tag using the Git tree, not just by SHA.

For example, if the app version is `0.4.0-alpha.1`, the release branch is `release/0.4` and the resulting beta tag is `v0.4.0-beta.1`.

## 5. Promotion to production

Before promotion, verify that the release is consistent with master:

```bash
git fetch origin
git merge-base --is-ancestor origin/master origin/release/2.8
```

If this fails, the branch is not ready for production. In that case, merge `master` into the release branch and re-run qualification.

If it passes, create or validate the GitLab Merge Request from the release branch to `master`.

## 6. Tagging production

After merge to `master`, the production tag is created from `master`:

```bash
git checkout master
git pull
git tag -a v2.8.3 -m "Release v2.8.3"
git push origin v2.8.3
```

This enforces the rule that `master` must exactly represent what is in production.
