"""Authenticated local XTest probe. Requires an existing DISPLAY/XAUTHORITY; installs nothing."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", type=Path, help="Fresh evidence directory; defaults to a new /tmp directory")
args = parser.parse_args()
project = Path(__file__).resolve().parents[2]
evidence = args.output_dir.resolve() if args.output_dir else Path(tempfile.mkdtemp(prefix="resonance-v2-os-evidence-"))
if (evidence / "os-input.log").exists():
    raise SystemExit("Output already contains a probe; choose a fresh directory")
evidence.mkdir(parents=True, exist_ok=True)
bridge = Path(tempfile.mkdtemp(prefix="resonance-v2-os-"))
request, ack = bridge / "request.json", bridge / "ack.json"
env = os.environ.copy()
if not env.get("DISPLAY") or not env.get("XAUTHORITY"):
    raise SystemExit("Set the existing authenticated DISPLAY and XAUTHORITY")
for key in ["DATA", "CONFIG", "CACHE"]:
    env["XDG_" + key + "_HOME"] = str(bridge / key.lower())
env["LIBGL_ALWAYS_SOFTWARE"] = "1"
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
display = x11.XOpenDisplay(env["DISPLAY"].encode())
if not display:
    raise SystemExit("Cannot open the authenticated local X11 display")
root_window = x11.XDefaultRootWindow(display)
x11.XResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_uint, ctypes.c_uint]
x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XKeysymToKeycode.restype = ctypes.c_uint
xtest.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
escape = x11.XKeysymToKeycode(display, 0xff1b)
last, game_window = -1, None
started = time.monotonic()
command = ["godot", "--path", str(project), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--resolution", "360x640", "--position", "40,40", "--script", "tools/v2/os_input_probe.gd", "--", "--no-save", "--bridge-dir=" + str(bridge)]
with (evidence / "os-input.log").open("w") as log:
    log.write(json.dumps({"command": command, "cwd": str(project), "xdg": {k: v for k, v in env.items() if k.startswith("XDG_")}}) + "\n")
    log.flush()
    process = subprocess.Popen(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        while process.poll() is None:
            if time.monotonic() - started > 420:
                raise TimeoutError("OS probe exceeded 420 seconds")
            try:
                item = json.loads(request.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(0.01)
                continue
            if item["sequence"] != last:
                if item["kind"] == "mouse":
                    child = ctypes.c_ulong()
                    tx, ty = ctypes.c_int(), ctypes.c_int()
                    x11.XTranslateCoordinates(display, root_window, root_window, item["x"], item["y"], ctypes.byref(tx), ctypes.byref(ty), ctypes.byref(child))
                    if child.value:
                        game_window = child.value
                        focus, revert = ctypes.c_ulong(), ctypes.c_int()
                        x11.XGetInputFocus(display, ctypes.byref(focus), ctypes.byref(revert))
                        if focus.value != game_window:
                            x11.XSetInputFocus(display, game_window, 2, 0)
                            x11.XSync(display, 0)
                            time.sleep(0.05)
                    xtest.XTestFakeMotionEvent(display, -1, item["x"], item["y"], 0)
                    if item["action"] != "move":
                        xtest.XTestFakeButtonEvent(display, 1, int(item["action"] == "press"), 0)
                    x11.XSync(display, 0)
                elif item["kind"] == "resize":
                    game_window = int(item["window"])
                    x11.XResizeWindow(display, game_window, item["width"], item["height"])
                    x11.XSync(display, 0)
                elif item["kind"] == "escape":
                    xtest.XTestFakeKeyEvent(display, escape, 1, 0)
                    xtest.XTestFakeKeyEvent(display, escape, 0, 0)
                    x11.XSync(display, 0)
                elif item["kind"] == "focus_out":
                    x11.XSetInputFocus(display, root_window, 2, 0)
                    x11.XSync(display, 0)
                    time.sleep(0.1)
                elif item["kind"] == "capture":
                    target = evidence / Path(item["name"]).name
                    native = x11.XGetImage(display, root_window, item["x"], item["y"], item["width"], item["height"], ctypes.c_ulong(-1).value, 2)
                    if not native:
                        raise RuntimeError("XGetImage failed")
                    try:
                        info = native.contents
                        if info.bits_per_pixel != 32 or info.byte_order != 0:
                            raise RuntimeError("Unexpected native pixel layout")
                        data = ctypes.string_at(info.data, info.bytes_per_line * info.height)
                        Image.frombytes("RGB", (info.width, info.height), data, "raw", "BGRX", info.bytes_per_line).save(target)
                    finally:
                        x11.XDestroyImage(native)
                else:
                    raise ValueError("Unexpected bridge request")
                last = item["sequence"]
                pending = ack.with_suffix(".tmp")
                pending.write_text(json.dumps({"sequence": last}))
                pending.replace(ack)
            time.sleep(0.01)
        log.write("\nEXIT=" + str(process.returncode) + "\n")
        print(json.dumps({"exit": process.returncode, "wall_seconds": round(time.monotonic() - started, 3)}))
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        x11.XCloseDisplay(display)
print((evidence / "os-input.log").read_text())
raise SystemExit(process.returncode)
