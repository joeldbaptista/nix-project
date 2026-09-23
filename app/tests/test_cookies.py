import duckdb

from fortune import cookies


def test_created_database_holds_every_saying(tmp_path):
    path = tmp_path / "cookie.duckdb"
    cookies.create(str(path))

    with duckdb.connect(str(path), read_only=True) as conn:
        rows = conn.execute("SELECT saying FROM cookie").fetchall()

    assert [row[0] for row in rows] == list(cookies.SAYINGS)


def test_create_overwrites_an_existing_file(tmp_path):
    """The image build runs create() into a fresh layer, but a rerun must not fail."""
    path = tmp_path / "cookie.duckdb"
    cookies.create(str(path))
    cookies.create(str(path))

    with duckdb.connect(str(path), read_only=True) as conn:
        count = conn.execute("SELECT count(*) FROM cookie").fetchone()[0]

    assert count == len(cookies.SAYINGS)


def test_connect_falls_back_to_memory_when_no_file_exists(tmp_path, monkeypatch):
    monkeypatch.setattr(cookies, "DB_PATH", str(tmp_path / "absent.duckdb"))

    conn = cookies.connect()
    assert cookies.random_saying(conn) in cookies.SAYINGS


def test_connect_reads_the_file_when_one_exists(tmp_path, monkeypatch):
    path = tmp_path / "cookie.duckdb"
    cookies.create(str(path))
    monkeypatch.setattr(cookies, "DB_PATH", str(path))

    conn = cookies.connect()
    assert cookies.random_saying(conn) in cookies.SAYINGS
