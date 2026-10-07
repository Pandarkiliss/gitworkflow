# Umbrella GitFlow + GitLab CI/CD

This repository is a practical template for an umbrella Git repository used to coordinate release creation, beta publication, and production promotion across multiple application repositories.

The design follows the GitFlow policy described in the project brief while adding a CI layer to enforce the required guardrails with GitLab.

## 1. Scope

The repo contains:

- a GitLab CI pipeline definition,
- example umbrella configuration in `charts/values.yaml`,
- reusable shell scripts for project discovery, release creation, beta handling, and promotion,
- operational documentation for GitFlow, release, beta, and production processes.

## 2. Explicit assumptions

This implementation makes a few assumptions that should be confirmed in the target environment:

- `GITLAB_RELEASE_TOKEN` has push, tag, and API permissions on all relevant repositories,
- the GitLab host is either `CI_SERVER_HOST` or `GITLAB_HOST`,
- `repository-name` is the GitLab project path and not the Docker image name,
- the umbrella release branch is configured through `UMBRELLA_RELEASE_BRANCH`,
- automatic Merge Requests are optional and require a valid target project path or project ID.

These are not hidden conventions: they are made explicit so that the workflow can be adapted to a real enterprise setup.

## 3. Structure

```text
.
├── .gitlab-ci.yml
├── README.md
├── charts/
│   └── values.yaml
├── docs/
│   ├── gitflow.md
│   ├── release-process.md
│   ├── beta-process.md
│   └── production-process.md
├── scripts/
│   ├── common.sh
│   ├── discover-projects.sh
│   ├── create-releases.sh
│   ├── create-beta.sh
│   ├── promote-production.sh
│   ├── update-umbrella.sh
│   └── gitlab-api.sh
└── templates/
    └── merge_request_body.json
```

The repository is intentionally structured as a clean umbrella repo. If you prefer a nested `umbrella/` folder for a monorepo layout, the same scripts can be moved there without changing the logic.

## 4. GitFlow rules followed

- `master`: exact production state
- `dev`: next sprint integration
- `release/*`: stabilization and QA
- `feature/*`: active development
- `fix/*`: corrections during a release
- `hotfix/*`: urgent production correction

Protected branches in GitLab:

- `master`
- `dev`
- `release/*`

The scripts enforce the required Git safety constraints:

- never rebase `master`, `dev`, `release/*`,
- allow rebase only on personal branches,
- never use `git push --force` on shared branches,
- use `git merge-base --is-ancestor` checks before release creation or production promotion.

## 5. CI variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `GITLAB_RELEASE_TOKEN` | Yes | OAuth token for cloning, pushing, tagging, and GitLab API calls |
| `UMBRELLA_RELEASE_BRANCH` | Yes | Branch used to update `charts/values.yaml` |
| `GITLAB_HOST` | Recommended | Hostname of the GitLab instance |
| `GITLAB_API_URL` | Recommended | Override for API URL |
| `GITLAB_PROJECT_PATH` | Optional | Target project path for Merge Requests |
| `GITLAB_PROJECT_ID` | Optional | Target project ID for Merge Requests |

No token is printed in logs.

## 6. Pipelines

### `validate`

Performs basic syntax validation:

- shell syntax checks for scripts,
- YAML validation for `charts/values.yaml`.

### `create-release`

Runs `scripts/create-releases.sh` and creates release branches for projects whose tags are in `-alpha.N` form, subject to the `master ⊆ dev` validation.

### `beta`

Runs `scripts/create-beta.sh` to:

- identify alpha/beta projects,
- create `vX.Y.Z-beta.N` tags when needed,
- skip unnecessary duplicate beta tags when no content has changed,
- patch `charts/values.yaml` directly on the umbrella release branch.

### `promote-production`

Runs `scripts/promote-production.sh` to verify `master ⊆ release/*` and prepare the production promotion workflow.

## 7. Installation and configuration

1. Ensure the GitLab runner includes `bash`, `git`, `curl`, and `python3`.
2. Define the required CI variables in GitLab.
3. Create the umbrella release branch if it does not already exist.
4. Apply a valid `charts/values.yaml` file.
5. Trigger the pipelines manually from GitLab UI or by running the scripts locally.

Example local usage:

```bash
bash scripts/create-releases.sh
bash scripts/create-beta.sh
bash scripts/promote-production.sh
```

## 8. Example logs

```text
[2026-10-07T08:30:00Z] [project-a] version=0.4.0-alpha.1
[2026-10-07T08:30:00Z] [project-a] release branch=release/0.4
[2026-10-07T08:30:00Z] [project-a] latest beta=none
[2026-10-07T08:30:00Z] [project-a] creating v0.4.0-beta.1
[2026-10-07T08:30:00Z] [project-a] umbrella updated

[2026-10-07T08:35:22Z] [project-b] version=2.8.3-alpha.2
[2026-10-07T08:35:22Z] [project-b] release branch=release/2.8
[2026-10-07T08:35:22Z] [project-b] latest beta=v2.8.3-beta.2
[2026-10-07T08:35:22Z] [project-b] no content change since v2.8.3-beta.2; skipping beta creation
```

## 9. Troubleshooting

### Release creation blocked

The most common cause is that `master` is not an ancestor of `dev`.

### Beta creation skipped

The script intentionally avoids creating an extra beta if the content has not changed since the last beta.

### Missing umbrella branch

Ensure `UMBRELLA_RELEASE_BRANCH` points to the correct umbrella release branch before the beta workflow runs.

### Merge Request is not created automatically

Either configure `GITLAB_PROJECT_PATH` or `GITLAB_PROJECT_ID`, or perform the Merge Request manually.

## 10. Security and conventions

- use `set -euo pipefail` in all scripts,
- no `--force` on shared branches,
- no rebase on protected branches,
- `--force-with-lease` only on personal branches,
- token values are never printed,
- failures are not silently ignored.

## 11. Detailed documentation

See the docs folder for the process playbooks:

- [docs/gitflow.md](docs/gitflow.md)
- [docs/release-process.md](docs/release-process.md)
- [docs/beta-process.md](docs/beta-process.md)
- [docs/production-process.md](docs/production-process.md)

## 12. Why this workflow is safe

This implementation prefers explicit guardrails and Git semantics over convenience:

- it uses `git merge-base --is-ancestor`, not SHA-only comparisons,
- it compares Git trees before creating a new beta tag,
- it updates the umbrella release branch directly instead of creating temporary CI branches,
- it strongly prefers Merge Requests for protected branches.

That makes the workflow suitable as a real enterprise baseline while remaining understandable for a team of around ten developers operating on three-week sprints.
