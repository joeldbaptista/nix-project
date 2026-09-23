# syntax=docker/dockerfile:1

# ---- build stage -------------------------------------------------------------
# Dependencies are installed into a virtual environment, so the runtime stage can
# copy one self-contained directory and carry no build tooling.
FROM python:3.13-slim AS build

WORKDIR /src

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY pyproject.toml ./
COPY src ./src

RUN pip install --no-cache-dir .

# The fortune cookie database is built here and copied into the runtime stage as
# a finished artifact, so the container serves it read-only and writes nothing.
# It belongs in the image for the same reason the application does: a Fargate
# task has no persistent storage, and every deployment replaces the task.
RUN python -m fortune.cookies /opt/data/cookie.duckdb

# ---- runtime stage -----------------------------------------------------------
FROM python:3.13-slim AS runtime

# The commit the image was built from. Overridden by the app pipeline.
ARG GIT_SHA=unknown
ENV GIT_SHA=${GIT_SHA}

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    COOKIE_DB_PATH=/opt/data/cookie.duckdb

RUN useradd --create-home --uid 10001 appuser

COPY --from=build /opt/venv /opt/venv
COPY --from=build /opt/data /opt/data

USER appuser
WORKDIR /home/appuser

EXPOSE 8080

CMD ["uvicorn", "fortune.main:app", "--host", "0.0.0.0", "--port", "8080"]
