"""Send local authenticated XTest pointer events. Usage: pointer.py move X Y | down | up | click X Y"""
import ctypes,os,sys,time
x11=ctypes.CDLL('libX11.so.6'); xt=ctypes.CDLL('libXtst.so.6')
x11.XOpenDisplay.restype=ctypes.c_void_p
x11.XOpenDisplay.argtypes=[ctypes.c_char_p]
x11.XFlush.argtypes=[ctypes.c_void_p]
x11.XCloseDisplay.argtypes=[ctypes.c_void_p]
xt.XTestFakeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
xt.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
d=x11.XOpenDisplay(os.environ.get('DISPLAY',':96').encode())
if not d:raise SystemExit('X display authentication/connection failed')
cmd=sys.argv[1]
if cmd in ['move','click']:xt.XTestFakeMotionEvent(d,-1,int(sys.argv[2]),int(sys.argv[3]),0)
if cmd in ['down','click']:xt.XTestFakeButtonEvent(d,1,1,0)
if cmd=='click':x11.XFlush(d);time.sleep(0.15)
if cmd in ['up','click']:xt.XTestFakeButtonEvent(d,1,0,0)
x11.XFlush(d);x11.XCloseDisplay(d)
