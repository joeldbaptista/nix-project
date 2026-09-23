"""HTTP entry points.

The service is deliberately small. Its purpose is to give the app pipeline
something real to lint, test, build, push and deploy, and to give the bastion
something to curl once the task is running in the private subnet.
"""

import os

from fastapi import FastAPI

from fortune import __version__, cookies

# Set by the app pipeline at image build time, so a running task can be traced
# back to the commit it was built from.
GIT_SHA = os.environ.get("GIT_SHA", "unknown")

app = FastAPI(title="fortune-app", version=__version__)

# Opened once at import rather than per request, because opening a database
# file on every call would dominate the cost of answering one. Each request
# takes its own cursor from it.
db = cookies.connect()


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe. Kept free of dependencies so it cannot fail for unrelated reasons."""
    return {"status": "ok"}


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": "fortune-app",
        "version": __version__,
        "commit": GIT_SHA,
        "saying": cookies.random_saying(db),
    }
