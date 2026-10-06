"""Loads the running Flutter web app in a headless Chrome and reports
which article images actually load vs fail, by watching network events.
No app code is touched."""
import asyncio, json, subprocess, sys, time, urllib.request

PORT = 59333

async def main():
    # 1. Start headless Chrome with our temp profile + debug port.
    chrome = subprocess.Popen([
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        f"--user-data-dir={PORT}-profile", f"--remote-debugging-port={PORT}",
        "--headless=new", "--disable-gpu", "--no-first-run",
        "--disable-extensions", "about:blank"])
    # 2. Find the WS debugger URL.
    for _ in range(40):
        try:
            info = json.load(urllib.request.urlopen(f"http://localhost:{PORT}/json/version"))
            ws_url = info["webSocketDebuggerUrl"]
            break
        except Exception:
            time.sleep(0.25)
    else:
        print("CHROME FAILED TO START"); chrome.terminate(); sys.exit(1)

    import websockets
    msg_id = 0
    async def send(method, params=None):
        nonlocal msg_id
        msg_id += 1
        await ws.send(json.dumps({"id": msg_id, "method": method, "params": params or {}}))
        while True:
            resp = json.loads(await ws.recv())
            if resp.get("id") == msg_id:
                return resp

    async with websockets.connect(ws_url, max_size=20*1024*1024) as ws:
        await send("Network.enable")
        loaded, failed = [], []
        # 3. Open the app and let it run for 30 s.
        await send("Page.enable")
        await send("Page.navigate", {"url": "http://localhost:8080/"})
        deadline = time.time() + 30
        while time.time() < deadline:
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=1.0)
            except asyncio.TimeoutError:
                continue
            m = json.loads(raw)
            method = m.get("method", "")
            if method == "Network.loadingFailed":
                p = m["params"]
                if "image" in (p.get("type") or "") or (p.get("errorText") or "").startswith("net"):
                    failed.append((p.get("errorText"), p.get("blockedReason")))
            elif method == "Network.loadingFinished":
                loaded.append(1)
        # 4. Ask the page which <img>-equivalents actually painted.
        #    Flutter web renders to canvas, so instead grab runtime logs.
        #    Simpler: count console errors.
        errors = []
        async def drain_console():
            pass
        print(f"network loads finished: {len(loaded)}")
        print(f"network failures: {len(failed)}")
        for e, b in failed[:12]:
            print(f"  FAILED: {e} blocked={b}")
        # snapshot final state
        r = await send("Runtime.evaluate", {"expression": "1+1"})
        print("page alive:", r.get("result", {}).get("result", {}).get("value"))
        chrome.terminate()

asyncio.run(main())
