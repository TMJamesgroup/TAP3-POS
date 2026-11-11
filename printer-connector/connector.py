"""TAP3 local printer connector: discovery and test-print API (Windows/Linux).
Run: python -m pip install flask pyusb; python connector.py
Local-only by default. This is a prototype; do not expose it to the internet.
"""
import os, json, socket, subprocess, platform, secrets
from flask import Flask, jsonify, request
app=Flask(__name__)
TOKEN=os.environ.get("TAP3_CONNECTOR_TOKEN") or secrets.token_urlsafe(32)
SUPPORTED={"epson-t88vii":"Epson TM-T88VII","star-tsp143iv-x4":"Star TSP143IV X4","epson-u220b":"Epson TM-U220B"}
def identify(name):
    n=name.lower().replace(" ","").replace("-","")
    if "t88vii" in n: return "epson-t88vii"
    if "tsp143iv" in n: return "star-tsp143iv-x4"
    if "u220" in n: return "epson-u220b"
    return None
def installed():
    if platform.system()=="Windows":
        cmd=["powershell","-NoProfile","-Command","Get-Printer | Select-Object Name,PortName,DriverName | ConvertTo-Json"]
        try:
            p=subprocess.run(cmd,capture_output=True,text=True,timeout=10,check=True)
            raw=json.loads(p.stdout) if p.stdout.strip() else []
            return raw if isinstance(raw,list) else [raw]
        except Exception:return []
    try:
        p=subprocess.run(["lpstat","-p"],capture_output=True,text=True,timeout=8)
        return [{"Name":x.split("printer ",1)[1].split(" is ",1)[0]} for x in p.stdout.splitlines() if x.startswith("printer ")]
    except Exception:return []
@app.after_request
def headers(r):
    r.headers["Cache-Control"]="no-store"
    r.headers["Access-Control-Allow-Origin"]="http://localhost:5173"
    return r
@app.get("/health")
def health():return jsonify(status="ok",connector="TAP3",version="0.1.0")
@app.get("/printers")
def printers():
    if request.headers.get("X-TAP3-Connector-Token")!=TOKEN:return jsonify(error="unauthorized"),401
    rows=installed()
    return jsonify(printers=[{"name":x.get("Name",""),"model":identify(x.get("Name","")),"supported":bool(identify(x.get("Name",""))),"port":x.get("PortName"),"driver":x.get("DriverName")} for x in rows])
@app.post("/test-print")
def test_print():
    if request.headers.get("X-TAP3-Connector-Token")!=TOKEN:return jsonify(error="unauthorized"),401
    body=request.get_json(silent=True) or {}
    name=body.get("name","")
    if name not in [x.get("Name") for x in installed()]:return jsonify(error="printer not installed"),404
    return jsonify(error="Direct print transport not enabled. No print job was sent."),501
if __name__=="__main__":
    print("TAP3 connector token:",TOKEN,flush=True)
    app.run(host="127.0.0.1",port=17843,debug=False)
