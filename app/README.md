# Fortune — the service

A minimal FastAPI service, containerised and deployed to ECS Fargate by
`.github/workflows/app.yml`. It serves fortune cookie sayings from a DuckDB
database baked into its image.

This file covers the application. The repository root's `README.md` covers the
infrastructure that runs it, and `docs/runbook.md` covers operating it.

## Endpoints

Two, and this is the complete list:

| Method and path | Response |
| --- | --- |
| `GET /health` | `{"status":"ok"}`. Free of dependencies, so it cannot fail for unrelated reasons |
| `GET /` | The service name, the version, the commit the image was built from, and a `saying` |

There is no public ingress in the deployed environment, so both are reached
through the SSM-managed bastion. Locally they are reached on port 8080.

## The fortune cookie database

The sayings live in DuckDB. The database holds one table, `cookie`, with one
`TEXT` column, `saying`, and `GET /` returns one row chosen at random by the
database rather than by Python.

The file is built during the image build, by
`python -m fortune.cookies /opt/data/cookie.duckdb`, and copied out of the
build stage into the runtime stage. So it is part of the image rather than
state the container creates, and the container opens it read-only. That suits
the platform: a Fargate task has no persistent storage, and every deployment
replaces the task.

Outside the image no file exists at that path, so `connect()` builds the same
database in memory from the same seed. Consequently the tests and a local
`uvicorn` run need no docker build.

To change the sayings, edit the `SAYINGS` tuple in `src/fortune/cookies.py` and
push. The app pipeline rebuilds the image, so the new database ships with it.

## Layout

| Path | Purpose |
| --- | --- |
| `src/fortune/main.py` | The two endpoints |
| `src/fortune/cookies.py` | The seed, and the functions that build, open and query the database |
| `src/fortune/__init__.py` | The version string |
| `tests/` | Nine pytest tests, over the endpoints and the database |
| `Dockerfile` | Multi-stage build, `python:3.13-slim`, non-root user, port 8080 |
| `Makefile` | Every routine development task |
| `pyproject.toml` | Dependencies, and the ruff and pytest configuration |

## Local development

`make help` prints the list below.

| Target | What it does |
| --- | --- |
| `help` | Default goal. Lists targets, then the current image, port and commit |
| `venv` | Creates `.venv` and installs `-e ".[dev]"` |
| `lint` | `ruff check` and `ruff format --check` |
| `format` | `ruff format` and `ruff check --fix` |
| `test` | `pytest -q` |
| `check` | `lint` then `test` |
| `build` | `docker build` with `GIT_SHA` from git |
| `run` | Builds, then runs in the foreground |
| `smoke` | Builds, starts detached, calls `/health` and `/`, removes the container |
| `serve` | `uvicorn --reload`, no container |
| `db` | Writes `./cookie.duckdb` for inspection |
| `seed` | Builds for x86_64 and pushes the seed image to ECR |
| `clean` | Removes caches, build output, the local database |
| `clean-all` | Also removes `.venv` and the local image |

Three points about it. The virtual environment installs itself on first use and
reinstalls only when `pyproject.toml` changes. `make check` runs the same two
gates the app pipeline does, so a green result predicts a green lint job and
test job. And `seed` is the only target that reaches AWS; everything else is
local.

Variables override on the command line, for example `make build TAG=v2`,
`make run PORT=9000`, or `make seed AWS_REGION=eu-central-1`.

The underlying commands, should you prefer them to the Makefile:

```bash
python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"
.venv/bin/ruff check . && .venv/bin/ruff format --check .
.venv/bin/pytest -q
docker build --build-arg GIT_SHA=local -t fortune-app:local .
docker run --rm -p 8080:8080 fortune-app:local
```

## The image

The build is multi-stage. The build stage installs the dependencies and the
application into a virtual environment at `/opt/venv`, then writes the cookie
database to `/opt/data`. The runtime stage copies those two directories and
nothing else, so the source tree never reaches the final image. The real value
of that split is the seam: a dependency that later needs a compiler gets one in
the build stage alone, and the runtime image stays as it is.

The container runs as uid 10001 on port 8080.

Two notes on architecture. The task definition declares `X86_64`, so a build on
an Apple Silicon machine that is destined for ECR needs
`--platform linux/amd64`; `make seed` passes it already. A plain `make build`
omits it deliberately, because a native image is faster to build and is only
ever run locally.

## How a change reaches production

Pushing to `main` under `app/**` triggers `.github/workflows/app.yml`, which
runs four jobs: lint, test, build and deploy. Those cover the diagram's five
stages, because pushing to ECR is a step inside the build job rather than a job
of its own.

The image carries two tags, the full commit SHA and a moving `main` pointer.
The SHA tag is what the task definition references, so every running task is
traceable to a commit, which `GET /` reports as `commit`.

Terraform owns the shape of the task definition and this pipeline owns only the
image tag. So the deploy job reads the current revision, replaces the image,
and registers a new revision from the result.

If the ephemeral layer is currently destroyed there is no service to update.
That is expected rather than a failure: the image is already in ECR, and the
next `env-up` run picks it up.
