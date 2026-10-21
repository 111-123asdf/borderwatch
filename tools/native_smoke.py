import ctypes
import json
import os
from pathlib import Path
import subprocess
import shutil
import time
from ctypes import wintypes


project_root = Path(__file__).resolve().parents[1]
state_path = Path(os.environ['APPDATA']) / 'Borderwatch' / 'qa_state.json'
user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.SetProcessDPIAware()
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
user32.SetForegroundWindow.argtypes = [wintypes.HWND]
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
checks = []
window_handle = None
process = subprocess.Popen([str(project_root / 'builds/windows-core-slice/Borderwatch.exe'), '--resolution', '1280x800', '--', '--qa-state', '--qa-capture'], cwd=project_root / 'builds/windows-core-slice')
mouse_position = (0, 0)


def state():
    for attempt in range(20):
        if process.poll() is not None:
            raise RuntimeError(f'Exported game exited: {process.returncode}')
        try:
            value = json.loads(state_path.read_text(encoding='utf-8'))
            if value.get('pid') == process.pid:
                return value
        except (OSError, json.JSONDecodeError):
            pass
        time.sleep(0.1)
    raise RuntimeError('No current QA state from exported executable')


def check(condition, message):
    checks.append({'check': message, 'passed': bool(condition)})
    if not condition:
        raise AssertionError(message)


def key(code, duration=0.09):
    scan = user32.MapVirtualKeyW(code, 0)
    user32.PostMessageW(window_handle, 0x0100, code, 1 | (scan << 16))
    time.sleep(duration)
    user32.PostMessageW(window_handle, 0x0101, code, 0xC0000001 | (scan << 16))
    time.sleep(0.18)


def client_geometry():
    rectangle = wintypes.RECT()
    user32.GetClientRect(window_handle, ctypes.byref(rectangle))
    point = wintypes.POINT(0, 0)
    user32.ClientToScreen(window_handle, ctypes.byref(point))
    return point.x, point.y, rectangle.right, rectangle.bottom


def move_mouse(logical_x, logical_y):
    global mouse_position
    left, top, width, height = client_geometry()
    mouse_position = (int(logical_x * width / 1280), int(logical_y * height / 800))
    user32.PostMessageW(window_handle, 0x0200, 0, mouse_position[0] | (mouse_position[1] << 16))


def mouse_button(pressed, right=False):
    message = (0x0204 if pressed else 0x0205) if right else (0x0201 if pressed else 0x0202)
    mask = (2 if right else 1) if pressed else 0
    user32.PostMessageW(window_handle, message, mask, mouse_position[0] | (mouse_position[1] << 16))


def click(logical_x, logical_y):
    move_mouse(logical_x, logical_y)
    time.sleep(0.08)
    mouse_button(True)
    time.sleep(0.1)
    mouse_button(False)
    time.sleep(0.25)


def capture_window():
    time.sleep(0.6)
    destination = project_root / 'test-results/0.3-native.png'
    shutil.copy2(state_path.parent / 'qa_window.png', destination)
    return str(destination)


try:
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    @callback_type
    def visit_window(handle, parameter):
        global window_handle
        identifier = wintypes.DWORD()
        user32.GetWindowThreadProcessId(handle, ctypes.byref(identifier))
        if identifier.value == process.pid and user32.IsWindowVisible(handle):
            window_handle = handle
            return False
        return True

    deadline = time.monotonic() + 20
    while window_handle is None and time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError('Export failed to open a game window')
        user32.EnumWindows(visit_window, 0)
        time.sleep(0.1)
    if window_handle is None:
        raise RuntimeError('Game window handle not found')
    time.sleep(0.6)
    check(state()['modal'] == 'title', 'Independent executable opens its title screen')
    print(json.dumps({'initial_capture': capture_window(), 'geometry': client_geometry()}), flush=True)
    click(620, 340)
    check(state()['class'] == 'ranger' and state()['weapon'] == 'bow', 'Hero card selects ranger and its starting weapon')
    click(970, 340)
    check(state()['class'] == 'mage' and state()['energy'] == 180, 'Hero card selects mage with distinct energy pool')
    click(300, 340)
    check(state()['class'] == 'knight' and state()['weapon'] == 'pistol', 'Hero card selects knight without copying another identity')
    click(950, 675)
    check(state()['started'] and state()['modal'] == '', 'Real mouse click starts gameplay')
    previous = state()['hero']
    key(ord('D'), 0.25)
    check(state()['hero'][0] > previous[0] + 25, 'Windows D key moves the hero')
    key(0x20)
    check(state()['skill_time'] > 4 and state()['dash_time'] == 0 and state()['dash_cooldown'] == 0, 'Space activates knight dual wield, not a universal dash')
    cooldown = state()['skill_cooldown']
    key(ord('C'))
    check(0 < state()['skill_cooldown'] < cooldown, 'C shares the same active skill cooldown as Space')
    key(0x09)
    check(state()['modal'] == 'inventory' and not state()['running'], 'Tab opens paused growth panel')
    key(0x09)
    check(state()['modal'] == '', 'Tab closes growth panel')
    for target in [(1184, 736), (1184, 928)]:
        current = state()
        screen_x = 640 + (target[0] - current['camera'][0]) * current['zoom']
        screen_y = 400 + (target[1] - current['camera'][1]) * current['zoom']
        click(screen_x, screen_y)
        check(state()['context'], 'Clicking marked ground opens contextual construction')
        popup_x = max(16, min(screen_x + 40, 974))
        popup_y = max(115, min(screen_y - 150, 475))
        click(popup_x + 145, popup_y + 86)
    check(state()['towers'] == 1 and state()['gold'] == 80, '180 starting gold pays for one 100-gold tower; second construction is rejected')
    check(state()['attacks'] == 0, 'Building clicks do not accidentally shoot')
    current = state()
    previous = current['hero']
    target_x = 640 + (previous[0] + 150 - current['camera'][0]) * current['zoom']
    target_y = 400 + (previous[1] - current['camera'][1]) * current['zoom']
    move_mouse(target_x, target_y)
    mouse_button(True, right=True)
    mouse_button(False, right=True)
    time.sleep(0.4)
    check(state()['hero'][0] > previous[0] + 25, 'Right-click command makes hero walk toward destination')
    key(ord('A'), 0.1)
    check(not state()['navigating'], 'Keyboard input overrides mouse navigation')
    current = state()
    previous = current['hero']
    hero_x = 640 + (previous[0] - current['camera'][0]) * current['zoom']
    hero_y = 400 + (previous[1] - 27 - current['camera'][1]) * current['zoom']
    click(hero_x, hero_y)
    click(hero_x, hero_y - 140)
    time.sleep(0.25)
    check(state()['hero'][1] < previous[1] - 25, 'Selecting hero then clicking ground issues walking command')
    key(ord('D'), 0.08)
    current = state()
    previous = current['hero']
    hero_x = 640 + (previous[0] - current['camera'][0]) * current['zoom']
    hero_y = 400 + (previous[1] - 27 - current['camera'][1]) * current['zoom']
    move_mouse(hero_x, hero_y)
    mouse_button(True)
    time.sleep(0.08)
    move_mouse(hero_x + 130, hero_y + 50)
    mouse_button(False)
    time.sleep(0.3)
    check(state()['hero'][0] > previous[0] + 25, 'Dragging hero onto ground makes hero walk rather than teleport')
    key(ord('A'), 0.08)
    move_mouse(940, 600)
    attacks = state()['attacks']
    mouse_button(True)
    time.sleep(0.6)
    check(state()['attacks'] > attacks, 'Held Windows mouse button performs weapon attacks')
    mouse_button(False)
    key(ord('F'))
    check(state()['modal'] == 'confirm' and state()['wave'] == 0, 'F opens early-start confirmation before the 90-second automatic wave')
    click(747, 475)
    check(state()['wave'] == 1 and state()['gold'] == 80, 'Early confirmation starts the first wave without a gold bonus')
    current = state()
    move_mouse(640 + (1450 - current['camera'][0]) * current['zoom'], 400 + (1050 - current['camera'][1]) * current['zoom'])
    mouse_button(True, right=True)
    mouse_button(False, right=True)
    deadline = time.monotonic() + 40
    while state()['target'] == [0, 0] and time.monotonic() < deadline:
        time.sleep(0.2)
    current = state()
    check(current['target'] != [0, 0], 'Visible enemies become automatically targeted in the standalone game')
    move_mouse(1100, 700)
    mouse_button(True)
    aimed_at_enemy = False
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        current = state()
        if current['target'] != [0, 0]:
            offset = [current['target'][0] - current['hero'][0], current['target'][1] - (current['hero'][1] - 27)]
            target_length = (offset[0] ** 2 + offset[1] ** 2) ** 0.5
            pointer_offset = [current['camera'][0] + 460 / current['zoom'] - current['hero'][0], current['camera'][1] + 300 / current['zoom'] - (current['hero'][1] - 27)]
            pointer_length = (pointer_offset[0] ** 2 + pointer_offset[1] ** 2) ** 0.5
            target_alignment = (offset[0] * current['aim'][0] + offset[1] * current['aim'][1]) / max(1, target_length)
            pointer_alignment = (pointer_offset[0] * current['aim'][0] + pointer_offset[1] * current['aim'][1]) / max(1, pointer_length)
            if target_alignment > 0.95 and pointer_alignment < 0.8:
                aimed_at_enemy = True
                break
        time.sleep(0.05)
    check(aimed_at_enemy, 'Hero faces the enemy rather than the far-right mouse pointer')
    mouse_button(False)
    key(0x1B)
    check(state()['modal'] == 'pause', 'Windows Escape opens pause')
    key(0x1B)
    check(state()['modal'] == '', 'Windows Escape resumes gameplay')
    left, top, width, height = client_geometry()
    screenshot_path = capture_window()
    report = {'method': 'Targeted Win32 key and pointer messages to the exported window; no global cursor takeover', 'checks': checks, 'screenshot': screenshot_path, 'executable_pid': process.pid, 'geometry': [left, top, width, height]}
    (project_root / 'test-results/native_smoke-0.3.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
finally:
    for code in [ord('D'), ord('A'), ord('C'), ord('F'), 0x09, 0x20, 0x1B]:
        user32.PostMessageW(window_handle, 0x0101, code, 0xC0000001 | (user32.MapVirtualKeyW(code, 0) << 16))
    mouse_button(False)
    if process.poll() is None:
        if window_handle is not None:
            user32.PostMessageW(window_handle, 0x0010, 0, 0)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.terminate()
