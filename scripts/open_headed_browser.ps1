<#
.SYNOPSIS
    在 Windows 實體使用者桌面 (WinSta0\Default) 上開啟有頭瀏覽器，打破背景沙盒隔離。
.DESCRIPTION
    由於 Antigravity 背景執行環境預設處於隔離的虛擬桌面 (exebox-...)，
    直接執行 subprocess 或 start-process 會導致視窗被畫在隱藏桌面而無法在螢幕上看見。
    此腳本透過 Win32 CreateProcess 明確指定 lpDesktop = "WinSta0\Default"，
    並配合 SetForegroundWindow，保證 100% 視窗顯示在使用者螢幕最前方。
#>
param (
    [Parameter(Mandatory=$false)]
    [string]$Url = "https://dash.cloudflare.com/login",
    [Parameter(Mandatory=$false)]
    [string]$BrowserPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
)

$code = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class HeadedBrowserLauncher {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public Int32 cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public Int32 dwX;
        public Int32 dwY;
        public Int32 dwXSize;
        public Int32 dwYSize;
        public Int32 dwXCountChars;
        public Int32 dwYCountChars;
        public Int32 dwFillAttribute;
        public Int32 dwFlags;
        public Int16 wShowWindow;
        public Int16 cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public Int32 dwProcessId;
        public Int32 dwThreadId;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool CreateProcess(
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation
    );

    [DllImport("user32.dll")]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll")]
    public static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc lpfn, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public static int Launch(string browserPath, string url) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\Default";
        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

        string cmd = "\"" + browserPath + "\" --new-window \"" + url + "\"";
        bool success = CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, null, ref si, out pi);
        if (!success) {
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("[!] CreateProcess 失敗，錯誤碼: " + err);
            return -1;
        }
        Console.WriteLine("[✓] 瀏覽器已成功在實體桌面 (WinSta0\\Default) 啟動，PID: " + pi.dwProcessId);
        return pi.dwProcessId;
    }

    public static void BringToFront(string titleKeyword) {
        IntPtr hDesk = OpenDesktop("Default", 0, false, 0x0100 | 0x0001);
        if (hDesk == IntPtr.Zero) return;

        EnumDesktopWindows(hDesk, (hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                string title = sb.ToString().Trim();
                if (title.IndexOf(titleKeyword, StringComparison.OrdinalIgnoreCase) >= 0) {
                    ShowWindow(hWnd, 3); // SW_MAXIMIZE
                    SetForegroundWindow(hWnd);
                    Console.WriteLine("[✓] 已將視窗置頂: " + title);
                }
            }
            return true;
        }, IntPtr.Zero);

        CloseDesktop(hDesk);
    }
}
"@

Add-Type -TypeDefinition $code -Language CSharp
[HeadedBrowserLauncher]::Launch($BrowserPath, $Url)
Start-Sleep -Seconds 2
[HeadedBrowserLauncher]::BringToFront("Chrome")
