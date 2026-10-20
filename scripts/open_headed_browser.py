#!/usr/bin/env python3
"""
在 Windows 實體使用者桌面 (WinSta0\\Default) 上開啟有頭瀏覽器。
確保視窗 100% 呈現在使用者眼前，打破背景虛擬桌面 (Desktop Isolation) 沙盒。
"""

import sys
import ctypes
from ctypes import wintypes

class STARTUPINFOW(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("lpReserved", wintypes.LPWSTR),
        ("lpDesktop", wintypes.LPWSTR),
        ("lpTitle", wintypes.LPWSTR),
        ("dwX", wintypes.DWORD),
        ("dwY", wintypes.DWORD),
        ("dwXSize", wintypes.DWORD),
        ("dwYSize", wintypes.DWORD),
        ("dwXCountChars", wintypes.DWORD),
        ("dwYCountChars", wintypes.DWORD),
        ("dwFillAttribute", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("wShowWindow", wintypes.WORD),
        ("cbReserved2", wintypes.WORD),
        ("lpReserved2", ctypes.c_void_p),
        ("hStdInput", wintypes.HANDLE),
        ("hStdOutput", wintypes.HANDLE),
        ("hStdError", wintypes.HANDLE),
    ]

class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("hProcess", wintypes.HANDLE),
        ("hThread", wintypes.HANDLE),
        ("dwProcessId", wintypes.DWORD),
        ("dwThreadId", wintypes.DWORD),
    ]

def open_headed_browser(url: str = "https://dash.cloudflare.com/login", browser_path: str = r"C:\Program Files\Google\Chrome\Application\chrome.exe") -> int:
    si = STARTUPINFOW()
    si.cb = ctypes.sizeof(STARTUPINFOW)
    si.lpDesktop = r"WinSta0\Default"  # 強制指定實體互動桌面
    
    pi = PROCESS_INFORMATION()
    cmd = f'"{browser_path}" --new-window "{url}"'
    
    CreateProcessW = ctypes.windll.kernel32.CreateProcessW
    success = CreateProcessW(
        None,
        cmd,
        None,
        None,
        False,
        0,
        None,
        None,
        ctypes.byref(si),
        ctypes.byref(pi),
    )
    
    if not success:
        err = ctypes.GetLastError()
        print(f"[!] CreateProcess 失敗，錯誤代碼: {err}")
        return -1
        
    print(f"[✓] 成功在實體桌面 (WinSta0\\Default) 啟動有頭瀏覽器！PID: {pi.dwProcessId}")
    return pi.dwProcessId

if __name__ == "__main__":
    target_url = sys.argv[1] if len(sys.argv) > 1 else "https://dash.cloudflare.com/login"
    open_headed_browser(target_url)
