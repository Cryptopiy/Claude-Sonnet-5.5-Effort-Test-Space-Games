import socket, json, sys
PORT = 9878
def send(cmd, params=None, timeout=300):
    s = socket.create_connection(("127.0.0.1", PORT), timeout=timeout)
    s.sendall(json.dumps({"type": cmd, "params": params or {}}).encode())
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk: break
        buf += chunk
        try:
            return json.loads(buf.decode())
        except Exception:
            continue
    return json.loads(buf.decode())
def run(code):
    r = send("execute_code", {"code": code})
    return r
if __name__ == "__main__":
    code = open(sys.argv[1]).read() if len(sys.argv) > 1 else "print(bpy.data.filepath)"
    r = run(code)
    print(json.dumps(r, indent=1)[:6000])
