#!/usr/bin/env python3
"""
Log Rotation Script — rotates app and system logs.
Run via cron: 0 2 * * * /usr/bin/python3 /opt/scripts/log-rotation.py
"""

import os
import gzip
import shutil
import logging
from datetime import datetime
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("log-rotation")

LOG_DIRS = ["/var/log/app", "/var/log/nginx", "/var/log/containers"]
MAX_AGE_DAYS = 30
COMPRESS_DAYS = 7
MAX_SIZE_MB = 100


def get_file_age_days(path: Path) -> float:
    mtime = datetime.fromtimestamp(path.stat().st_mtime)
    return (datetime.now() - mtime).total_seconds() / 86400


def get_file_size_mb(path: Path) -> float:
    return path.stat().st_size / (1024 * 1024)


def rotate_logs(log_dir: Path):
    if not log_dir.exists():
        logger.warning(f"Directory not found: {log_dir}")
        return

    logger.info(f"Processing: {log_dir}")

    for log_file in log_dir.glob("*"):
        if not log_file.is_file() or log_file.suffix == ".gz":
            continue

        age = get_file_age_days(log_file)
        size_mb = get_file_size_mb(log_file)

        if age > MAX_AGE_DAYS:
            logger.info(f"  DELETE: {log_file.name} (age={age:.1f}d)")
            log_file.unlink()
            continue

        if age > COMPRESS_DAYS or size_mb > MAX_SIZE_MB:
            compressed = log_file.with_suffix(log_file.suffix + ".gz")
            logger.info(f"  COMPRESS: {log_file.name} -> {compressed.name}")
            ts = datetime.now().strftime("%Y%m%d-%H%M%S")
            rotated = log_file.with_name(f"{log_file.stem}-{ts}{log_file.suffix}")
            shutil.move(str(log_file), str(rotated))
            with open(rotated, "rb") as fin:
                with gzip.open(str(rotated) + ".gz", "wb") as fout:
                    shutil.copyfileobj(fin, fout)
            rotated.unlink()

    total = sum(f.stat().st_size for f in log_dir.glob("*") if f.is_file())
    logger.info(f"  Total after rotation: {total/1024/1024:.1f}MB")


def main():
    logger.info("Starting log rotation...")
    for log_dir in LOG_DIRS:
        rotate_logs(Path(log_dir))
    logger.info("Log rotation complete.")


if __name__ == "__main__":
    main()