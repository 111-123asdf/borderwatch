"""Windows native-window probe; GODOT_BIN points to Godot 4.7.2.

Uses fixture gold/enemy and targeted window messages, not a real playthrough.
"""
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

project = Path(__file__).resolve().parents[1]
godot = Path(os.environ['GODOT_BIN'])
# The Windows console wrapper launches a child with another PID; address the
# GUI binary directly so every window message is restricted to our process.
if godot.name.endswith('_console.exe'):
    godot = godot.with_name(godot.name.replace('_console.exe', '.exe'))
if not godot.is_file():
    raise FileNotFoundError(f'Godot GUI binary not found: {godot}')
run_dir = Path(tempfile.mkdtemp(prefix='arena-build-window-'))
env = os.environ.copy()
env['BW_PROBE_DIR'] = str(run_dir)
env['APPDATA'] = str(run_dir / 'Roaming')
env['LOCALAPPDATA'] = str(run_dir / 'Local')
env['APPDATA'] and Path(env['APPDATA']).mkdir(parents=True)
env['LOCALAPPDATA'] and Path(env['LOCALAPPDATA']).mkdir(parents=True)
user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.SetProcessDPIAware()
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
process = subprocess.Popen([godot, '--path', str(project), '--resolution', '1280x800', '--script', 'res://tests/arena_build_window_probe.gd'], cwd=project, env=env)
handle = None
checks = []
point = (0, 0)

def state():
    for _ in range(60):
        if process.poll() is not None:
            raise RuntimeError(f'Fixture exited early: {process.returncode}')
        try:
            data = json.loads((run_dir / 'state.json').read_text(encoding='utf-8'))
            if data.get('pid') == process.pid:
                return data
        except (OSError, ValueError):
            pass
        time.sleep(.05)
    raise RuntimeError('No state from fixture')

def check(condition, message):
    checks.append((bool(condition), message))
    print(('PASS: ' if condition else 'FAIL: ') + message, flush=True)
    if not condition:
        raise AssertionError(message)

def key(code):
    scan = user32.MapVirtualKeyW(code, 0)
    user32.PostMessageW(handle, 0x100, code, 1 | (scan << 16))
    time.sleep(.09)
    user32.PostMessageW(handle, 0x101, code, 0xC0000001 | (scan << 16))
    time.sleep(.3)

def move(logical):
    global point
    r = wintypes.RECT()
    user32.GetClientRect(handle, ctypes.byref(r))
    s = state()['viewport']
    point = (int(logical[0] * r.right / s[0]), int(logical[1] * r.bottom / s[1]))
    user32.PostMessageW(handle, 0x200, 0, point[0] | (point[1] << 16))
    time.sleep(.1)

def mouse(down, right=False):
    message = (0x204 if down else 0x205) if right else (0x201 if down else 0x202)
    user32.PostMessageW(handle, message, (2 if right else 1) if down else 0, point[0] | (point[1] << 16))

def click(logical, right=False, duration=.12):
    move(logical)
    mouse(True, right)
    time.sleep(duration)
    mouse(False, right)
    time.sleep(.3)

try:
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    @callback_type
    def visit(candidate, _):
        global handle
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(candidate, ctypes.byref(pid))
        if pid.value == process.pid and user32.IsWindowVisible(candidate):
            handle = candidate
            return False
        return True
    deadline = time.monotonic() + 30
    while handle is None and time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f'Fixture exited: {process.returncode}')
        user32.EnumWindows(visit, 0)
        time.sleep(.1)
    if handle is None:
        raise RuntimeError('Own fixture window not found')
    state()
    time.sleep(.8)
    key(0x42)
    time.sleep(.8)
    s = state()
    check(s['build_mode'], 'B enters construction mode')
    target = s['center']
    check(bool(target), 'buildable cell is visible')
    before = s['towers']
    click(target['point'])
    s = state()
    check(s['selected'] and s['cell'] == target['cell'], 'click selects exact location')
    check(s['palette'] and s['towers'] == before and len(s['buttons']) == 7, 'seven choices open before construction')
    check((run_dir / 'build-menu.png').is_file(), 'build menu screenshot saved')
    print('SCREENSHOT:', run_dir / 'build-menu.png', flush=True)
    shots = s['shots']
    move(s['buttons'][0])
    mouse(True)
    time.sleep(.5)
    s = state()
    # Godot buttons normally fire on mouse release: verify neither firing nor building prematurely.
    check(s['shots'] == shots, 'holding the choice does not fire')
    mouse(False)
    time.sleep(.5)
    s = state()
    check(s['towers'] == before + 1 and not s['build_mode'], 'tower is built after choosing')
    check(s['shots'] == shots, 'choosing and releasing does not fire')
    key(0x42)
    time.sleep(.7)
    s = state()
    target = s['edge']
    check(bool(target), 'edge-area cell is visible')
    click(target['point'])
    s = state()
    check(s['selected'] and s['palette'], 'edge-area selection opens menu')
    x, y, w, h = s['panel_rect']
    vw, vh = s['viewport']
    check(x >= 0 and y >= 0 and x + w <= vw + .1 and y + h <= vh + .1, 'edge menu remains within viewport')
    key(0x48)
    s = state()
    check(s['guide'] and not s['build_mode'] and not s['palette'], 'opening H guide dismisses build menu')
    before = s['towers']
    key(0x42)
    click(target['point'])
    s = state()
    check(s['guide'] and not s['build_mode'] and s['towers'] == before, 'guide blocks building')
    key(0x48)
    check(not state()['guide'], 'H closes guide')
    key(0x42)
    time.sleep(.7)
    target = state()['edge']
    click(target['point'])
    check(state()['selected'], 'building can restart after closing guide')
    click(target['point'], right=True)
    check(not state()['selected'], 'right click closes selection')
    key(0x1B)
    check(not state()['build_mode'], 'Escape exits construction mode')
    for index, kind in [(4, 'venom'), (5, 'laser'), (6, 'banner')]:
        key(0x42)
        time.sleep(.7)
        target = state()['center']
        click(target['point'])
        s = state()
        check(s['selected'], f'{kind} site is selectable')
        click(s['buttons'][index])
        s = state()
        check(kind in s['kinds'], f'{kind} tower builds')
    time.sleep(.5)
    check((run_dir / 'tower-examples.png').is_file(), 'tower screenshot saved')
    print('TOWER SCREENSHOT:', run_dir / 'tower-examples.png', flush=True)
    print(f'CHECKS: {len(checks)}, FAILURES: 0', flush=True)
finally:
    if handle is not None:
        user32.PostMessageW(handle, 0x10, 0, 0)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.terminate()
        process.wait(timeout=5)
