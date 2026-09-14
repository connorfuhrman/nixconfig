import json
import os
import sys


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(path, cfg):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, separators=(",", ":"))
        fh.write("\n")
    os.replace(tmp, path)


def extra_sources(cfg, sources):
    drop = set(sources)
    return [m.get("Source") for m in (cfg.get("Mounts") or []) if m.get("Source") in drop]


def prune(path, sources):
    cfg = load(path)
    drop = set(sources)
    mounts = cfg.get("Mounts") or []
    kept = [m for m in mounts if m.get("Source") not in drop]
    if len(kept) == len(mounts):
        print("unchanged")
        return 0
    cfg["Mounts"] = kept
    save(path, cfg)
    print("changed")
    return 0


def main(argv):
    if len(argv) < 4:
        print("usage: ensure-volumes.py --status|--prune JSON SOURCE...", file=sys.stderr)
        return 1
    mode, path = argv[1], argv[2]
    sources = argv[3:]
    if mode == "--status":
        extra = extra_sources(load(path), sources)
        print("needed" if extra else "unchanged")
        return 0
    if mode == "--prune":
        return prune(path, sources)
    print("unknown mode {}".format(mode), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
