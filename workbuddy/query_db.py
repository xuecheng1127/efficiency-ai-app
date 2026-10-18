import sqlite3
import sys
import datetime


def fmt_ts(v):
    """Drift dateTime 默认存 unix 秒；转成可读时间。"""
    if v is None:
        return None
    try:
        iv = int(v)
        # 秒级时间戳（10 位）；毫秒（13 位）则先除 1000
        if iv > 10_000_000_000:
            iv = iv // 1000
        return datetime.datetime.fromtimestamp(iv).strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return v


TIME_COLS = {
    "startDate", "endDate", "createdAt", "archivedAt",
    "occurrenceDate", "startedAt", "completedAt", "deletedAt",
}


def dump(db_path):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    print("=== tables ===")
    for r in c.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
        print("  " + r[0])

    for t in ("task_templates", "task_instances"):
        print("\n=== %s ===" % t)
        cols = [d[1] for d in c.execute("PRAGMA table_info(%s)" % t)]
        print("  columns: " + ",".join(cols))
        n = c.execute("SELECT COUNT(*) FROM %s" % t).fetchone()[0]
        print("  count = %d" % n)
        for r in c.execute("SELECT * FROM %s" % t):
            d = dict(zip(cols, r))
            for k in list(d):
                if k in TIME_COLS:
                    d[k] = fmt_ts(d[k])
            print("  " + str(d))

    conn.close()


if __name__ == "__main__":
    dump(sys.argv[1])
