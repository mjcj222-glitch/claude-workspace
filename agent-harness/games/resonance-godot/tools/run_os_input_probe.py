"""Drive the real X11 window through XTest; never call game action methods."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import time
from PIL import Image

project = Path(__file__).resolve().parents[1]
evidence = project / "evidence/local-integration"
request = evidence / "os-request.json"
ack = evidence / "os-ack.json"
request.unlink(missing_ok=True)
ack.unlink(missing_ok=True)
env = os.environ.copy()
env.update(DISPLAY=":91", XAUTHORITY="/tmp/resonance-local-display/Xauthority",
           LIBGL_ALWAYS_SOFTWARE="1", XDG_DATA_HOME="/tmp/resonance-local-data",
           XDG_CONFIG_HOME="/tmp/resonance-local-config", XDG_CACHE_HOME="/tmp/resonance-local-cache")
os.environ.update({k: env[k] for k in ["DISPLAY", "XAUTHORITY"]})
x11 = ctypes.CDLL("libX11.so.6")
xtest = ctypes.CDLL("libXtst.so.6")
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x11.XDefaultRootWindow.restype = ctypes.c_ulong
x11.XTranslateCoordinates.argtypes = [ctypes.c_void_p,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_ulong)]
x11.XGetInputFocus.argtypes = [ctypes.c_void_p,ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_int)]
x11.XSetInputFocus.argtypes = [ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_ulong]
class XImage(ctypes.Structure):
    _fields_ = [("width",ctypes.c_int),("height",ctypes.c_int),("xoffset",ctypes.c_int),
                ("format",ctypes.c_int),("data",ctypes.c_void_p),("byte_order",ctypes.c_int),
                ("bitmap_unit",ctypes.c_int),("bitmap_bit_order",ctypes.c_int),
                ("bitmap_pad",ctypes.c_int),("depth",ctypes.c_int),("bytes_per_line",ctypes.c_int),
                ("bits_per_pixel",ctypes.c_int),("red_mask",ctypes.c_ulong),
                ("green_mask",ctypes.c_ulong),("blue_mask",ctypes.c_ulong)]
x11.XGetImage.argtypes = [ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.c_uint,ctypes.c_uint,ctypes.c_ulong,ctypes.c_int]
x11.XGetImage.restype = ctypes.POINTER(XImage)
x11.XDestroyImage.argtypes = [ctypes.POINTER(XImage)]
xtest.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtest.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(b":91")
if not display:
    raise SystemExit("Cannot open the authenticated local X11 display")
root_window = x11.XDefaultRootWindow(display)
last = -1
started = time.monotonic()
with (evidence / "os-input-matrix.log").open("w") as log:
    process = subprocess.Popen(
        ["godot", "--path", str(project), "--audio-driver", "Dummy", "--resolution", "360x640",
         "--position", "40,40", "--script", "tools/os_input_probe.gd", "--", "--no-save"],
        env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        while process.poll() is None:
            if time.monotonic() - started > 300:
                raise TimeoutError("OS probe exceeded 300 seconds")
            try:
                item = json.loads(request.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(0.02)
                continue
            if item["sequence"] != last:
                if item["kind"] == "mouse":
                    child = ctypes.c_ulong()
                    tx,ty = ctypes.c_int(),ctypes.c_int()
                    x11.XTranslateCoordinates(display,root_window,root_window,item["x"],item["y"],ctypes.byref(tx),ctypes.byref(ty),ctypes.byref(child))
                    if child.value:
                        focus,revert = ctypes.c_ulong(),ctypes.c_int()
                        x11.XGetInputFocus(display,ctypes.byref(focus),ctypes.byref(revert))
                        if focus.value != child.value:
                            print(json.dumps({"focus_before":focus.value,"window_under_pointer":child.value}),flush=True)
                            x11.XSetInputFocus(display,child.value,2,0)
                            x11.XSync(display,0)
                            time.sleep(0.1)
                    xtest.XTestFakeMotionEvent(display, -1, item["x"], item["y"], 0)
                    xtest.XTestFakeButtonEvent(display, 1, int(item["pressed"]), 0)
                    x11.XSync(display, 0)
                elif item["kind"] == "capture":
                    target = evidence / Path(item["name"]).name
                    native = x11.XGetImage(display,root_window,item["x"],item["y"],item["width"],item["height"],ctypes.c_ulong(-1).value,2)
                    if not native: raise RuntimeError("XGetImage failed")
                    try:
                        info = native.contents
                        if info.bits_per_pixel != 32 or info.byte_order != 0:
                            raise RuntimeError("Unexpected native pixel layout")
                        data = ctypes.string_at(info.data,info.bytes_per_line*info.height)
                        Image.frombytes("RGB",(info.width,info.height),data,"raw","BGRX",info.bytes_per_line).save(target)
                    finally:
                        x11.XDestroyImage(native)
                else:
                    raise ValueError("Unexpected bridge request")
                last = item["sequence"]
                pending_ack = ack.with_suffix(".tmp")
                pending_ack.write_text(json.dumps({"sequence": last}))
                pending_ack.replace(ack)
            time.sleep(0.02)
        print(json.dumps({"exit": process.returncode, "seconds": round(time.monotonic()-started, 2)}))
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        x11.XCloseDisplay(display)
print((evidence / "os-input-matrix.log").read_text())
raise SystemExit(process.returncode)
