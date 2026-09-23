"""The fortune cookie database.

The sayings live in DuckDB rather than in a Python list, so the service reads
its content from a real database. The database file is built during the image
build and opened read-only at runtime, which means the running container never
writes to it. That matches the platform: a Fargate task has no persistent
storage, and every deployment replaces the task.

Outside the image the file does not exist, so an in-memory database is built
from the same seed instead. Consequently the tests and a local `uvicorn` run
work without a docker build.
"""

import os
import sys
from pathlib import Path

import duckdb

# The seed. It is the only place a saying is written, and both the file
# database and the in-memory fallback are populated from it.
SAYINGS: tuple[str, ...] = (
    "A journey of a thousand miles begins with a single step.",
    "Your hard work will soon be rewarded.",
    "A friend asks only for your time, not for your money.",
    "You will find what you seek in an unexpected place.",
    "Patience is the companion of wisdom.",
    "A smile is the shortest distance between two people.",
    "The greatest risk is the one you never take.",
    "News from far away will reach you before the month is out.",
    "Curiosity is the wick in the candle of learning.",
    "Fortune favours the prepared mind.",
    "Do not mistake activity for achievement.",
    "The best time to plant a tree was twenty years ago. The second best time is now.",
    "To be sure of hitting your target, shoot first, then call whatever you hit the target.",
)

# Where the built database sits inside the image. The Dockerfile sets this
# variable, so a local run falls back to the default and finds no file.
DB_PATH = os.environ.get("COOKIE_DB_PATH", "/opt/data/cookie.duckdb")

# DuckDB sizes its thread pool and its memory limit from the machine it can
# see, which inside a container may be the host rather than the task's share of
# it. The task is 0.25 vCPU and 512 MiB, so both are pinned to something the
# task can actually afford.
CONFIG = {"threads": 1, "memory_limit": "128MB"}


def _populate(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("CREATE TABLE cookie (saying TEXT NOT NULL)")
    conn.executemany(
        "INSERT INTO cookie (saying) VALUES (?)",
        [(saying,) for saying in SAYINGS],
    )


def create(path: str) -> None:
    """Write a fresh database at `path`. Called by the image build, never at runtime."""
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.unlink(missing_ok=True)

    with duckdb.connect(str(target)) as conn:
        _populate(conn)


def connect() -> duckdb.DuckDBPyConnection:
    """Open the database the service reads from, building it in memory if no file exists."""
    path = Path(DB_PATH)

    if path.exists():
        return duckdb.connect(str(path), read_only=True, config=CONFIG)

    conn = duckdb.connect(":memory:", config=CONFIG)
    _populate(conn)
    return conn


def random_saying(conn: duckdb.DuckDBPyConnection) -> str:
    """Return one saying, chosen by the database rather than by Python."""
    # cursor() hands this call its own handle on the same database. FastAPI
    # runs a synchronous endpoint in a worker thread, so two requests can be in
    # flight at once, and one connection object is not meant to be shared
    # across threads.
    with conn.cursor() as cursor:
        row = cursor.execute("SELECT saying FROM cookie ORDER BY random() LIMIT 1").fetchone()

    return row[0]


if __name__ == "__main__":
    create(sys.argv[1])
