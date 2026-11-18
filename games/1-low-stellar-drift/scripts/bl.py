import socket,json,sys
code=open(sys.argv[1]).read()
s=socket.create_connection(("localhost",9877),timeout=300)
s.sendall(json.dumps({"type":"execute_code","params":{"code":code}}).encode())
buf=b""
while True:
    d=s.recv(65536)
    if not d:break
    buf+=d
    try:
        json.loads(buf);break
    except: pass
print(buf.decode()[:3000])
