"""Minimal Blender MCP socket client. Hard-wired to port 9882 (this project's Blender instance).

All calls are serialized across processes with a lock file, so several agents can share the one
Blender instance without interleaving their scripts. NEVER bypass this client with your own socket code.

Usage:
    python tools/bmcp.py info                 # scene info
    python tools/bmcp.py file script.py       # execute a python file inside Blender
    python tools/bmcp.py code "print(1+1)"    # execute inline code

Every script you run must be SELF-CONTAINED (create -> verify -> export in ONE call): do not rely on
selection / active object / mode state left behind by a previous call, another agent may have changed it.
"""
import json
import os
import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 9882  # NEVER change: other ports belong to other agents.
LOCK = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".bmcp.lock")
LOCK_STALE_S = 900


def _acquire():
    t0 = time.time()
    while True:
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(LOCK) > LOCK_STALE_S:
                    os.remove(LOCK)
                    continue
            except OSError:
                pass
            if time.time() - t0 > 1800:
                raise TimeoutError("bmcp lock wait > 30 min")
            time.sleep(0.25)


def _release():
    try:
        os.remove(LOCK)
    except OSError:
        pass


def _send(cmd_type, params=None, timeout=600):
    msg = json.dumps({"type": cmd_type, "params": params or {}}).encode("utf-8")
    with socket.create_connection((HOST, PORT), timeout=10) as s:
        s.settimeout(timeout)
        s.sendall(msg)
        buf = b""
        while True:
            chunk = s.recv(1 << 16)
            if not chunk:
                break
            buf += chunk
            try:
                return json.loads(buf.decode("utf-8"))
            except json.JSONDecodeError:
                continue
    return json.loads(buf.decode("utf-8")) if buf else {"status": "error", "message": "empty response"}


def send(cmd_type, params=None, timeout=600):
    _acquire()
    try:
        return _send(cmd_type, params, timeout)
    finally:
        _release()


def run_code(code, timeout=600):
    return send("execute_code", {"code": code}, timeout)


def show(resp):
    if isinstance(resp, dict) and resp.get("status") == "success":
        res = resp.get("result")
        if isinstance(res, dict) and "result" in res and len(res) <= 2:
            print(res["result"])
        else:
            print(json.dumps(res, indent=2, ensure_ascii=False))
    else:
        print("ERROR:", json.dumps(resp, indent=2, ensure_ascii=False))
        sys.exit(1)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "info"
    if mode == "info":
        show(send("get_scene_info"))
    elif mode == "file":
        with open(sys.argv[2], "r", encoding="utf-8") as f:
            show(run_code(f.read()))
    elif mode == "code":
        show(run_code(sys.argv[2]))
    else:
        print(__doc__)
