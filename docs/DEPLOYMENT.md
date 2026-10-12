# Production deployment of the backend

The backend runs on the homelab host with podman and `compose.prod.yml`. A
deployment is started by hand from GitHub (**Actions → Deploy Backend → Run
workflow**), only by the repository owner, and executed by a self-hosted runner
that reaches the host over SSH. Merging to `main` publishes the image
(`ghcr.io/theoleuthardt/backlog-manager-backend:<git sha>`, also `latest`) but
never deploys.

## What `deploy/deploy.sh` does

Installed next to `compose.prod.yml` on the host. Argument (or
`SSH_ORIGINAL_COMMAND`, last word): a full git SHA, or a tag or digest of the
backend image; anything else is refused.

1. refuses to run when another deployment holds the lock, the backup script is
   missing or the database container `blm_db` is not running
2. runs `backup.sh`; a failing backup aborts before anything is changed
3. pulls the image; when it is the one already running the script stops
   (`BLM_FORCE=1` redeploys it)
4. removes only `blm_backend` (with its dependents, the two cron containers,
   which podman ties to it) and recreates the backend and the cron containers
   with `up -d --no-deps --no-recreate`; the database is never touched (without
   `--no-recreate` this podman-compose recreates every existing container)
5. verifies the three containers run, the backend runs the requested image,
   `/health` answers and Alembic is at the head; the exit code of
   `podman-compose up` is not trusted because 1.x also complains about the
   already existing database container

There is no automatic rollback: the new image may already have migrated the
schema and an older image cannot start on an Alembic revision it does not
know. A failed deploy prints the log tail, the previous image
(`.previous-image` / `.deployed-image` next to the script) and leaves the
pre-deploy dump in the backup directory. To go back deploy the previous image
with `deploy.sh <previous>`, restoring the dump first when the migration is
not backward compatible.

Changes to `compose.prod.yml` and `deploy.sh` itself are **not** transferred
by the workflow (a compromised runner must not be able to inject a compose
file); copy them to the host by hand when they change, before deploying the
commit that needs them.

## One-time setup

### Host (where `compose.prod.yml` lives)

```bash
install -m 0755 deploy/deploy.sh /root/blm/deploy.sh
```

Create a key pair on the **runner** (below) and add the public key on the host
in `~/.ssh/authorized_keys`, restricted to the script:

```
restrict,command="/root/blm/deploy.sh" ssh-ed25519 AAAA... blm-deploy-runner
```

`restrict` disables shell, port forwarding and agent forwarding; the forced
command means the key can only ever start the deploy script.

### Runner (separate small Debian LXC, outbound connections only)

Follow GitHub's instructions (Settings → Actions → Runners → New self-hosted
runner), as an unprivileged user, never root, with the label `deploy`:

```bash
./config.sh --url https://github.com/theoleuthardt/backlog-manager \
  --token <registration token> --name blm-deploy-1 --labels deploy
sudo ./svc.sh install runner-user && sudo ./svc.sh start
```

Then, still as that user: `ssh-keygen -t ed25519 -f ~/.ssh/blm-deploy`, an
`~/.ssh/config` entry named like the `DEPLOY_HOST` variable, and
`ssh-keyscan <host> >> ~/.ssh/known_hosts` (the workflow uses
`StrictHostKeyChecking=yes`). The private key stays on the runner and is not
a GitHub secret.

Several runners can share one machine: unpack the runner package in a separate
directory per runner (`actions-runner-1`, `actions-runner-2`, ...), configure
each with its own `--name` and install each as its own service. Every runner
executes one job at a time, so N runners run N jobs in parallel; give them
enough CPU and RAM for that.

### GitHub

- Settings → Environments → **production**: Required reviewers = the owner,
  restrict deployment branches to `main`.
- Environment variable `DEPLOY_HOST` = the SSH host name of the production
  host as configured on the runner.

## Security model

- The workflow has only the `workflow_dispatch` trigger, runs on `main` only,
  and its job requires `github.actor == 'theoleuthardt'` plus the approval of
  the `production` environment.
- The repository is public, so **no workflow that runs for pull requests may
  use the self-hosted runner**: a fork could submit a PR that executes
  arbitrary code on the homelab machine. Only this dispatch-only workflow uses
  the `deploy` label; CI stays on GitHub-hosted runners (free and unlimited
  for public repositories). Keep "Require approval for all outside
  collaborators" enabled for fork pull requests.
- The runner machine has no inbound exposure, holds no database access and no
  application secrets, and can only start `deploy.sh` on the host.
- The image reference is validated by the script itself (repository, tag and
  digest pattern), independent of the workflow.
