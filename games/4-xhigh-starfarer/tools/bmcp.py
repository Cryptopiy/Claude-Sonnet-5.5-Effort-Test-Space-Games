"""Tiny client for the Blender MCP add-on socket (port 9880 ONLY).

Usage:
    python tools/bmcp.py scene                 -> get_scene_info
    python tools/bmcp.py run path/to/script.py -> execute_code with the file contents
    python tools/bmcp.py code "print(1+1)"     -> execute_code with an inline string
"""
import json
import socket
import sys

HOST = "127.0.0.1"
PORT = 9880  # this project's Blender instance. Never change.


def send(cmd_type, params=None, timeout=600):
    s = socket.create_connection((HOST, PORT), timeout=10)
    s.settimeout(timeout)
    s.sendall(json.dumps({"type": cmd_type, "params": params or {}}).encode("utf-8"))
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
        try:
            return json.loads(buf.decode("utf-8"))
        except json.JSONDecodeError:
            continue
    s.close()
    return json.loads(buf.decode("utf-8"))


def run_code(code, timeout=600):
    return send("execute_code", {"code": code}, timeout)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    mode = sys.argv[1]
    if mode == "scene":
        res = send("get_scene_info")
    elif mode == "run":
        with open(sys.argv[2], "r", encoding="utf-8") as f:
            res = run_code(f.read())
    elif mode == "code":
        res = run_code(sys.argv[2])
    else:
        print(__doc__)
        return
    out = json.dumps(res, indent=2, ensure_ascii=False)
    sys.stdout.reconfigure(encoding="utf-8")
    # unescape the captured stdout so it is readable
    if isinstance(res, dict) and isinstance(res.get("result"), dict) and "result" in res["result"]:
        print(res.get("status"))
        print(res["result"]["result"])
    else:
        print(out)


if __name__ == "__main__":
    main()
