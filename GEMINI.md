# HomeInventory Project Rules (家庭庫存管理系統專案規範)

## 有頭瀏覽器 (Headed Browser) 規範
當使用者指示「開出有頭瀏覽器」或需要使用者互動登入時：
1. **定義**：瀏覽器視窗必須 100% 呈現在使用者實體桌面（`WinSta0\Default`），肉眼可見。
2. **調用規範**：
   - 嚴禁使用無頭或未指定桌面的背景 subprocess。
   - 必須使用已封裝的專案工具：
     - PowerShell: `powershell -ExecutionPolicy Bypass -File .\scripts\open_headed_browser.ps1 -Url "<URL>"`
     - Python: `python scripts/open_headed_browser.py "<URL>"`
3. **已驗證原理**：
   透過 Win32 `CreateProcess` 傳遞 `lpDesktop = @"WinSta0\Default"` 打破背景虛擬桌面隔離，並透過 `SetForegroundWindow` 置頂。
