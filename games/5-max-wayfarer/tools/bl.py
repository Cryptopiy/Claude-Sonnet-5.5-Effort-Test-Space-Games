"""Tiny client for the Blender MCP add-on socket (port 9881 ONLY).

Usage:
  python tools/bl.py info                      -> scene info
  python tools/bl.py code "print(1+1)"         -> run python code inside Blender, print stdout
  python tools/bl.py file path/to/script.py    -> run a script file inside Blender (exec)
  python tools/bl.py shot out.png [max_size]   -> viewport screenshot
"""
import json, socket, sys, os

HOST, PORT = "127.0.0.1", 9881   # this agent's port - never change
EXPECTED_BLEND = r"W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\max_effort.blend"

def send(cmd_type, params=None, timeout=600):
    s = socket.create_connection((HOST, PORT), timeout=timeout)
    s.settimeout(timeout)
    s.sendall(json.dumps({"type": cmd_type, "params": params or {}}).encode("utf-8"))
    buf = b""
    while True:
        chunk = s.recv(1 << 20)
        if not chunk:
            break
        buf += chunk
        try:
            return json.loads(buf.decode("utf-8"))
        except json.JSONDecodeError:
            continue
    s.close()
    return json.loads(buf.decode("utf-8")) if buf else {"status": "error", "message": "empty response"}

def run_code(code):
    return send("execute_code", {"code": code})

def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    mode = sys.argv[1]
    if mode == "info":
        print(json.dumps(send("get_scene_info"), indent=2))
    elif mode == "code":
        r = run_code(sys.argv[2])
        out = r.get("result", r)
        if isinstance(out, dict) and "result" in out:
            print(out["result"])
        else:
            print(json.dumps(r, indent=2))
    elif mode == "file":
        path = os.path.abspath(sys.argv[2])
        code = "exec(compile(open(r'%s', encoding='utf-8').read(), r'%s', 'exec'))" % (path, path)
        r = run_code(code)
        out = r.get("result", r)
        if isinstance(out, dict) and "result" in out:
            print(out["result"])
        else:
            print(json.dumps(r, indent=2))
    elif mode == "shot":
        r = send("get_viewport_screenshot", {"max_size": int(sys.argv[3]) if len(sys.argv) > 3 else 800,
                                             "filepath": os.path.abspath(sys.argv[2]), "format": "png"})
        print(json.dumps(r, indent=2))
    else:
        print(__doc__)

if __name__ == "__main__":
    main()
