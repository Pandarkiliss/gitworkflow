# Beta process

The beta process transforms application versions that are still in alpha to beta tags and then updates the umbrella chart in the umbrella release branch.

## 1. Selecting projects

The pipeline reads each project entry under `charts/values.yaml` and ignores the top-level `global` block.

Only projects with a tag containing either:

- `-alpha.`
- `-beta.`

are considered.

## 2. Mapping version to release branch

A version such as:

- `0.4.0-alpha.1` => `release/0.4`
- `2.8.3-alpha.2` => `release/2.8`

The version is converted using the major/minor pair before the first patch field.

## 3. Beta creation rules

### Case 1: no beta exists

If no `vX.Y.Z-beta.*` tag exists, the pipeline creates:

```bash
v0.4.0-beta.1
```

This is intentionally mandatory, even if the release branch and alpha tag currently point to the same commit.

### Case 2: a beta already exists

If the latest beta is `v0.4.0-beta.2`, the pipeline compares:

```bash
git diff --quiet "v0.4.0-beta.2^{tree}" "origin/release/0.4^{tree}"
```

If the tree is identical, no new beta is created.

If the tree differs, a new beta is created:

```bash
v0.4.0-beta.3
```

## 4. Safety check

If a beta exists, the script verifies that the last beta commit is an ancestor of the release branch:

```bash
git merge-base --is-ancestor v0.4.0-beta.2 origin/release/0.4
```

If this fails, the pipeline stops and logs a clear message because the release branch has diverged from the last beta.

## 5. Tag creation

The beta tag is created on the head of the release branch:

```bash
git tag -a v0.4.0-beta.3 origin/release/0.4 -m "Release v0.4.0-beta.3"
git push origin v0.4.0-beta.3
```

## 6. Updating the umbrella release branch

The umbrella chart update must be applied directly to the umbrella release branch, not to a temporary CI branch.

Example:

```yaml
project-a:
  deployment:
    image:
      tag: "0.4.0-beta.3"
```

The script then commits and pushes the change:

```bash
git add charts/values.yaml
git commit -m "chore: update project-a to 0.4.0-beta.3"
git push origin <umbrella-release-branch>
```

This is done only for projects that actually received a new beta tag.
