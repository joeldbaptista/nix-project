# Fortune

A containerised FastAPI service running on ECS Fargate in a private subnet,
provisioned entirely by Terraform and deployed by GitHub Actions. The service
serves fortune cookie sayings from a DuckDB database baked into its image.

The project exists to demonstrate a complete infrastructure-as-code and CI/CD
setup in a single AWS account, at a cost low enough to leave running. Region is
`eu-west-1`.

## The service

A minimal FastAPI service with two endpoints, `GET /health` and `GET /`, which
returns the running commit and a fortune cookie saying. It is documented in
[`app/README.md`](app/README.md), along with its DuckDB database, its image and
its development targets.

## Architecture

Five decisions shape the design, and this list is exhaustive.

1. **No public ingress.** There is no load balancer and no public route to the
   service. It is reached through an SSM-managed bastion instead.
2. **No NAT Gateway.** VPC interface endpoints for `ecr.api`, `ecr.dkr` and
   `logs` let a task in a subnet with no default route pull its image and write
   its logs. A free S3 gateway endpoint serves the image layers themselves.
3. **Cloud Map instead of a load balancer.** A Fargate task receives a new
   private IP on every deployment, so the service is addressed by the stable
   name `app.fortune.internal:8080`.
4. **A manual approval gate.** The infra pipeline's apply job declares a
   GitHub Environment with a required reviewer. That also makes the OIDC
   subject claim environment-scoped, and the apply role trusts only that claim,
   so an unapproved apply is refused by AWS rather than merely hidden by the
   GitHub interface.
5. **Two Terraform layers, split by cost behaviour.** See below.

Authentication to AWS uses GitHub OIDC throughout. No long-lived access key
exists anywhere in the project.

## The two Terraform layers

The split is by cost behaviour rather than by lifecycle stage, because the
cheapest environment is one whose chargeable resources do not exist overnight.

**Durable** holds everything free or nearly free: the VPC, subnets, Internet
Gateway, route tables, security groups, the S3 gateway endpoint, the ECR
repository, both ECS IAM roles, the ECS cluster, the task definition, the log
group, and the Cloud Map namespace. It stays applied permanently and costs
under 1 EUR a month.

**Ephemeral** holds everything billed by the hour: the three interface
endpoints, the ECS service with its Cloud Map registration, and the bastion
with its public IPv4 address and EBS volume. It costs roughly 37 EUR a month
while it exists, it is destroyed nightly, and it takes about three minutes to
recreate.

The ephemeral layer reads the durable layer's outputs through a
`terraform_remote_state` data source. The dependency runs one way only, so the
ephemeral layer can be destroyed at any time without affecting the durable one.

## Pipelines

Four workflows, and this list is complete.

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `app.yml` | Push to `main` under `app/**` | Lint, test, build, push to ECR, update the ECS service |
| `infra.yml` | Push to `main` under `infra/**` | `terraform plan` on every push, then `apply` behind the approval gate |
| `env-down.yml` | 21:00 UTC nightly, or manual | Destroys the ephemeral layer |
| `env-up.yml` | Manual | Recreates the ephemeral layer and rolls the service onto the newest image |

The two path filters are mutually exclusive in practice: a change under `app/`
runs the app pipeline, and a change under `infra/` runs the infra pipeline.

## Repository layout

| Path | Purpose |
| --- | --- |
| `app/` | The service, its tests, its Dockerfile and its Makefile. See [`app/README.md`](app/README.md) |
| `infra/bootstrap/` | State bucket, OIDC provider, CI roles, budget. Applied by hand, once |
| `infra/layers/durable/` | Free or near-free resources. Applied permanently |
| `infra/layers/ephemeral/` | Hourly-billed resources. Destroyed nightly |
| `infra/modules/` | Nine building blocks used by the two layers |
| `.github/workflows/` | The four pipelines |
| `docs/runbook.md` | How to deploy, verify, operate and tear down |
| `diagram/` | The architecture diagram, in draw.io format |

## Testing locally

Nothing below touches AWS, and none of it needs credentials. The two units are
tested separately, because each carries its own Makefile.

### The application

```bash
cd app
make check    # ruff check, ruff format --check, then pytest
make smoke    # build the image, call both endpoints, remove the container
```

`make check` runs the same two gates the app pipeline runs, so a green result
predicts a green lint job and test job.

To hold the service open and call it by hand, use one of these, then curl from
a second terminal:

```bash
make serve    # uvicorn on 127.0.0.1:8080 with reload, no container
make run      # the container, in the foreground on port 8080
```

```bash
curl localhost:8080/health
curl localhost:8080/
```

Both accept `PORT=9000` to move off 8080. `make serve` reports
`"commit":"unknown"`, because the commit is stamped into the image at build
time and no image is involved. `app/README.md` documents the rest.

### The infrastructure

```bash
cd infra
make check    # terraform fmt -check -recursive, then validate in all three roots
```

That is the static half of what the infra pipeline's plan job does. The
planning half needs credentials and an applied state, so it cannot run until
bootstrap has been applied.

## Cost

Approximate monthly cost in `eu-west-1`:

| State | EUR/month |
| --- | --- |
| Ephemeral layer running | ~38 |
| Ephemeral layer destroyed | ~1 |

Two facts drive the design. Interface endpoints are billed for existing and
cannot be stopped. A stopped EC2 instance still incurs its EBS charge. So the
only measure that actually reaches zero is destruction, which is what
`env-down` performs. An AWS Budget notifies at 50%, 80% and 100% of actual
spend, and at 100% of forecast spend.

## Getting started

`docs/runbook.md` carries the full procedure, and `infra/Makefile` wraps the
Terraform commands it uses. Run `make help` in `infra/` for the list. In
outline, and in this order:

1. `make bootstrap-apply` in `infra/`, from your own machine. It creates the
   state bucket, the OIDC provider, the three CI roles and the budget.
2. `make vars`, which publishes the bootstrap outputs as GitHub repository
   variables.
3. Create two GitHub Environments: `infra-apply` with yourself as a required
   reviewer, and `env-lifecycle` with no protection rules.
4. `make apply-durable` in `infra/`, then `make seed` in `app/` to push the
   first image, then `make apply-ephemeral`. The ordering matters, because an
   ECS service cannot start a task from an empty repository.
5. `make verify` or `make session` in `infra/`, to reach the service through
   the bastion.

## Status

No AWS resource exists yet. All code is written and statically verified, but
nothing has been applied, so the project currently costs nothing. `STATUS.md`
records what is done, what blocks progress, and what comes next.

## Documentation

| File | Contents |
| --- | --- |
| `app/README.md` | The service: endpoints, database, image, and development targets |
| `PLAN.md` | The design and the reasoning behind every decision |
| `STATUS.md` | Where the work stands, and what to do next |
| `docs/runbook.md` | Operating procedures: deploy, verify, operate, tear down |
| `diagram/fortune-diagram.drawio` | The architecture as presented. Phase 8 will reconcile it with what was built |
