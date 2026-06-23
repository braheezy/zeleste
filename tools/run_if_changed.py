#!/usr/bin/env python3
"""Run an asset command only when declared inputs or outputs changed."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path


CACHE_VERSION = 1
LOCK_POLL_SECONDS = 0.05
LOCK_STALE_SECONDS = 300


def parse_args() -> tuple[argparse.Namespace, list[str]]:
    if len(sys.argv) == 3 and sys.argv[1] == "--reset-progress":
        path = Path(sys.argv[2])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("0\n")
        raise SystemExit(0)

    if "--" not in sys.argv:
        raise SystemExit("usage: run_if_changed.py [cache args] -- command [args...]")
    separator = sys.argv.index("--")
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--job", required=True)
    parser.add_argument("--input", type=Path, action="append", default=[])
    parser.add_argument("--input-dir", type=Path, action="append", default=[])
    parser.add_argument("--output", type=Path, action="append", default=[])
    parser.add_argument("--output-dir", type=Path, action="append", default=[])
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--progress-file", type=Path)
    parser.add_argument("--progress-total", type=int, default=0)
    parser.add_argument("--progress-width", type=int, default=20)
    args = parser.parse_args(sys.argv[1:separator])
    command = sys.argv[separator + 1 :]
    if not command:
        raise SystemExit("missing command after --")
    return args, command


def update_hash(hasher: "hashlib._Hash", value: str) -> None:
    encoded = value.encode("utf-8", errors="surrogateescape")
    hasher.update(len(encoded).to_bytes(8, "little"))
    hasher.update(encoded)


def hash_file(hasher: "hashlib._Hash", path: Path, label: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"input file missing for {label}: {path}")
    update_hash(hasher, f"file:{label}")
    update_hash(hasher, str(path))
    with path.open("rb") as file:
        while True:
            chunk = file.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)


def iter_directory_files(path: Path) -> list[Path]:
    if not path.is_dir():
        raise FileNotFoundError(f"input directory missing: {path}")
    files: list[Path] = []
    for root, dirnames, filenames in os.walk(path):
        dirnames.sort()
        for filename in sorted(filenames):
            files.append(Path(root) / filename)
    return files


def hash_directory(hasher: "hashlib._Hash", path: Path) -> None:
    update_hash(hasher, "dir")
    update_hash(hasher, str(path))
    for file in iter_directory_files(path):
        relative = file.relative_to(path).as_posix()
        update_hash(hasher, relative)
        hash_file(hasher, file, relative)


def fingerprint(args: argparse.Namespace, command: list[str]) -> str:
    hasher = hashlib.sha256()
    update_hash(hasher, f"asset-cache-v{CACHE_VERSION}")
    update_hash(hasher, args.job)
    for part in command:
        update_hash(hasher, part)
    for path in sorted(args.input, key=lambda item: str(item)):
        hash_file(hasher, path, path.name)
    for path in sorted(args.input_dir, key=lambda item: str(item)):
        hash_directory(hasher, path)
    return hasher.hexdigest()


def outputs_exist(args: argparse.Namespace) -> bool:
    for path in args.output:
        if not path.is_file():
            return False
    for path in args.output_dir:
        if not path.is_dir():
            return False
        try:
            next(path.rglob("*"))
        except StopIteration:
            return False
    return True


def read_cache(path: Path) -> dict:
    if not path.is_file():
        return {"version": CACHE_VERSION, "jobs": {}}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return {"version": CACHE_VERSION, "jobs": {}}
    if data.get("version") != CACHE_VERSION or not isinstance(data.get("jobs"), dict):
        return {"version": CACHE_VERSION, "jobs": {}}
    return data


def write_cache(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)


@contextmanager
def cache_lock(path: Path):
    lock = path.with_suffix(path.suffix + ".lock")
    lock.parent.mkdir(parents=True, exist_ok=True)
    while True:
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            with os.fdopen(fd, "w") as file:
                file.write(f"{os.getpid()}\n")
            break
        except FileExistsError:
            try:
                age = time.time() - lock.stat().st_mtime
                if age > LOCK_STALE_SECONDS:
                    lock.unlink()
                    continue
            except FileNotFoundError:
                continue
            time.sleep(LOCK_POLL_SECONDS)
    try:
        yield
    finally:
        try:
            lock.unlink()
        except FileNotFoundError:
            pass


def should_run(args: argparse.Namespace, digest: str) -> bool:
    if args.force or os.environ.get("ASSET_FORCE") == "1":
        return True
    if not outputs_exist(args):
        return True
    with cache_lock(args.cache):
        cache = read_cache(args.cache)
        job = cache["jobs"].get(args.job)
        return not isinstance(job, dict) or job.get("fingerprint") != digest


def mark_complete(args: argparse.Namespace, digest: str) -> None:
    with cache_lock(args.cache):
        cache = read_cache(args.cache)
        cache["jobs"][args.job] = {
            "fingerprint": digest,
            "outputs": [str(path) for path in args.output],
            "output_dirs": [str(path) for path in args.output_dir],
        }
        write_cache(args.cache, cache)


def report_progress(args: argparse.Namespace, rebuilt: bool) -> None:
    if args.quiet or args.progress_file is None or args.progress_total <= 0:
        if rebuilt and not args.quiet:
            print(f"asset cache miss: {args.job}")
        return

    width = max(1, args.progress_width)
    with cache_lock(args.progress_file):
        try:
            previous = int(args.progress_file.read_text().strip() or "0")
        except (FileNotFoundError, ValueError):
            previous = 0
        current = previous + 1
        args.progress_file.parent.mkdir(parents=True, exist_ok=True)
        args.progress_file.write_text(f"{current}\n")

    display_current = ((current - 1) % args.progress_total) + 1
    filled = max(1, (display_current * width) // args.progress_total)
    bar = "#" * filled + "-" * (width - filled)
    suffix = " cache miss" if rebuilt else ""
    line = f"assets [{bar}] {display_current:02d}/{args.progress_total:02d} {args.job}{suffix}"
    if sys.stdout.isatty():
        end = "\n" if display_current == args.progress_total else "\r"
        print(f"\r{line}\x1b[K", end=end, flush=True)
    elif display_current == args.progress_total:
        print(f"assets [{bar}] {display_current:02d}/{args.progress_total:02d} complete")


def run_command(command: list[str]) -> int:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
    return result.returncode


def main() -> int:
    args, command = parse_args()
    digest = fingerprint(args, command)
    if not should_run(args, digest):
        report_progress(args, rebuilt=False)
        return 0

    returncode = run_command(command)
    if returncode != 0:
        return returncode
    if not outputs_exist(args):
        missing = [str(path) for path in args.output if not path.is_file()]
        missing += [str(path) for path in args.output_dir if not path.is_dir()]
        print(f"asset job {args.job} did not produce expected outputs: {', '.join(missing)}", file=sys.stderr)
        return 1
    mark_complete(args, digest)
    report_progress(args, rebuilt=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
