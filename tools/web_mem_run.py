"""Drive the Atomic Robot web build in a dedicated Chrome and log memory + fps.

Chrome runs with background throttling off, so rAF keeps running even when the
window is not focused. Memory = sum of private bytes of this profile's processes.
"""
import json, subprocess, sys, time, urllib.request, os
import websocket

PROF = sys.argv[1]
URL = sys.argv[2]
OUT = sys.argv[3]
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9333

chrome = subprocess.Popen([CHROME, f"--user-data-dir={PROF}", f"--remote-debugging-port={PORT}",
    "--window-size=1280,860", "--no-first-run", "--no-default-browser-check",
    "--autoplay-policy=no-user-gesture-required", "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows",
    "--disable-extensions", "about:blank"])
for _ in range(50):
    try:
        tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json"))
        page = [t for t in tabs if t["type"] == "page"][0]
        break
    except Exception:
        time.sleep(0.2)
ws = websocket.create_connection(page["webSocketDebuggerUrl"], suppress_origin=True)
mid = 0
def cdp(method, **params):
    global mid
    mid += 1
    ws.send(json.dumps({"id": mid, "method": method, "params": params}))
    while True:
        m = json.loads(ws.recv())
        if m.get("id") == mid:
            return m.get("result", m.get("error"))

def js(expr):
    r = cdp("Runtime.evaluate", expression=expr, returnByValue=True, awaitPromise=True)
    return r.get("result", {}).get("value")

VK = {"Enter": 13, "ArrowRight": 39, "ArrowLeft": 37, "f": 70, "Space": 32}
def key(k, typ):
    code = {"f": "KeyF", "Space": "Space"}.get(k, k)
    keyname = {"Space": " "}.get(k, k)
    cdp("Input.dispatchKeyEvent", type=typ, key=keyname, code=code, windowsVirtualKeyCode=VK[k], nativeVirtualKeyCode=VK[k])
def tap(k, hold=0.08):
    key(k, "keyDown"); time.sleep(hold); key(k, "keyUp")

def mem():
    ps = ("Get-CimInstance Win32_Process -Filter \"name='chrome.exe'\" | Where-Object { $_.CommandLine -like '*" + os.path.basename(PROF) + "*' } | "
          "ForEach-Object { $t = if ($_.CommandLine -match '--type=([a-z-]+)') { $matches[1] } else { 'browser' }; \"$t $($_.PrivatePageCount) $($_.WorkingSetSize)\" }")
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout
    tot = {}
    for line in out.split("\n"):
        p = line.split()
        if len(p) == 3:
            t = p[0]; tot.setdefault(t, [0, 0]); tot[t][0] += int(p[1]); tot[t][1] += int(p[2])
    return {k: round(v[0] / 1048576) for k, v in tot.items()}, round(sum(v[0] for v in tot.values()) / 1048576)

FPS_JS = """(async()=>{const a=[];let l=performance.now();await new Promise(r=>{function f(t){a.push(t-l);l=t;if(a.length<240)requestAnimationFrame(f);else r()}requestAnimationFrame(f)});
a.shift();const s=[...a].sort((x,y)=>x-y);return {fps:Math.round(1000*a.length/a.reduce((x,y)=>x+y,0)),p50:+s[s.length>>1].toFixed(1),max:+s[s.length-1].toFixed(1),over25:a.filter(x=>x>25).length}})()"""
HEAP_JS = "performance.memory ? Math.round(performance.memory.usedJSHeapSize/1048576) : -1"

log = []
def sample(label):
    by, total = mem()
    rec = {"t": round(time.time() - t0, 1), "label": label, "total_mb": total, "by_type": by,
           "js_heap_mb": js(HEAP_JS), "frames": js(FPS_JS)}
    log.append(rec); print(json.dumps(rec), flush=True)

cdp("Page.enable"); cdp("Runtime.enable")
t0 = time.time()
cdp("Page.navigate", url=URL)
time.sleep(20); sample("title")
tap("Enter"); time.sleep(4); sample("after title press")
tap("Enter"); time.sleep(5); sample("char select -> splash")
tap("Enter"); time.sleep(3); tap("Enter"); time.sleep(16); sample("main intro")
# play: walk right, attack now and then
for i in range(10):
    key("ArrowRight", "keyDown")
    for _ in range(6):
        time.sleep(0.4); tap("f")
    key("ArrowRight", "keyUp")
    for _ in range(4):
        tap("f"); time.sleep(0.5)
    sample(f"play {i}")
json.dump(log, open(OUT, "w"), indent=1)
ws.close(); chrome.terminate()
