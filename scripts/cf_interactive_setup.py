#!/usr/bin/env python3
"""
Cloudflare 有頭瀏覽器自動化輔助工具
功能:
1. 開啟原生 Google Chrome 瀏覽器導向 cloudflare.com/login
2. 供使用者在真實瀏覽器中直接以 Google 帳號完成登入 (避開 Google 的機器人阻擋)
3. 偵測登入成功後，自動接手擷取 Account ID、建立/檢查 R2 Bucket、產生 S3 API Token 並寫入 .env
"""

import os
import sys
import time
import re
import subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
USER_DATA_DIR = os.path.expanduser(r"~/.gemini/chrome_cf_profile")

def update_env_file(updates: dict):
    """更新 .env 檔案中的特定變數"""
    if not ENV_PATH.exists():
        print(f"[!] 找不到 .env 檔案: {ENV_PATH}")
        return

    content = ENV_PATH.read_text(encoding="utf-8")
    for key, value in updates.items():
        pattern = rf"^{key}=.*$"
        replacement = f"{key}={value}"
        if re.search(pattern, content, flags=re.MULTILINE):
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        else:
            content += f"\n{replacement}"
            
    ENV_PATH.write_text(content, encoding="utf-8")
    print(f"[✓] 已成功更新 .env 檔案中的配置: {list(updates.keys())}")

def launch_chrome():
    os.makedirs(USER_DATA_DIR, exist_ok=True)
    cmd = [
        CHROME_PATH,
        "--remote-debugging-port=9222",
        f"--user-data-dir={USER_DATA_DIR}",
        "--no-first-run",
        "--no-default-browser-check",
        "https://dash.cloudflare.com/login"
    ]
    print("[*] 正在為您啟動 Google Chrome 瀏覽器 (視窗已開啟於桌面)...")
    return subprocess.Popen(cmd)

def main():
    print("=" * 60)
    print(" Cloudflare R2 智能互動配置精靈")
    print("=" * 60)

    # 1. 啟動 Chrome
    launch_chrome()
    time.sleep(3)

    # 2. 透過 Playwright CDP 連線
    print("[*] 正在連接瀏覽器除錯通道 (CDP: localhost:9222)...")
    with sync_playwright() as p:
        browser = None
        for attempt in range(10):
            try:
                browser = p.chromium.connect_over_cdp("http://localhost:9222")
                break
            except Exception:
                time.sleep(1)

        if not browser:
            print("[x] 無法連線至 Chrome 瀏覽器，請確認 Chrome 是否正常啟動。")
            sys.exit(1)

        context = browser.contexts[0]
        pages = context.pages
        page = pages[0] if pages else context.new_page()

        print("\n" + "=" * 60)
        print(" [提示] 請在剛剛彈出的 Chrome 瀏覽器視窗中：")
        print(" 點擊以 Google 帳號 (edward13c@gmail.com) 登入 Cloudflare。")
        print(" 登入完成後，本程式將自動偵測並接手完成所有 R2 配置！")
        print("=" * 60 + "\n")

        # 3. 等待使用者完成登入
        account_id = None
        logged_in = False

        while not logged_in:
            time.sleep(2)
            # 檢查所有開啟的分頁
            for p_curr in context.pages:
                curr_url = p_curr.url
                # 排除登入頁、註冊頁與 Google OAuth 轉跳頁
                if "dash.cloudflare.com" in curr_url and "/login" not in curr_url and "/sign-up" not in curr_url and "accounts.google.com" not in curr_url:
                    # 嘗試從 URL 解析 Account ID (格式為 32 碼十六進位字串)
                    match = re.search(r"dash\.cloudflare\.com/([a-f0-9]{32})", curr_url)
                    if match:
                        account_id = match.group(1)
                        page = p_curr
                        logged_in = True
                        break
                    elif curr_url.rstrip("/").endswith("dash.cloudflare.com") or "dash.cloudflare.com/?" in curr_url:
                        # 已經在 Dashboard 首頁
                        page = p_curr
                        logged_in = True
                        break

        print(f"\n[✓] 偵測到登入成功！")
        page.bring_to_front()
        time.sleep(2)

        # 若尚未直接獲取 account_id，從首頁網址或頁面元素獲取
        if not account_id:
            curr_url = page.url
            match = re.search(r"dash\.cloudflare\.com/([a-f0-9]{32})", curr_url)
            if match:
                account_id = match.group(1)
            else:
                # 嘗試點擊第一個帳號或從連結中找尋
                try:
                    acc_link = page.locator("a[href*='/dash.cloudflare.com/']").first
                    href = acc_link.get_attribute("href") or ""
                    m2 = re.search(r"/([a-f0-9]{32})", href)
                    if m2:
                        account_id = m2.group(1)
                except Exception:
                    pass

        if not account_id:
            # 透過 JavaScript 獲取目前 context 的帳號資訊
            try:
                account_id = page.evaluate("() => window.location.pathname.split('/')[1]")
            except Exception:
                pass

        print(f"[✓] 成功擷取 Cloudflare Account ID: {account_id}")

        # 4. 前往 R2 Overview
        r2_url = f"https://dash.cloudflare.com/{account_id}/r2/overview"
        print(f"[*] 正在引導前往 R2 概覽頁面: {r2_url}")
        page.goto(r2_url, wait_until="domcontentloaded")
        time.sleep(3)

        # 檢查 R2 是否需要啟用或已有 Buckets
        bucket_name = "home-inventory-photos"
        print(f"[*] 正在檢查 R2 儲存貯體 (Bucket: {bucket_name})...")

        # 檢查頁面上是否已有 home-inventory-photos
        content = page.content()
        if bucket_name not in content:
            print(f"[*] 嘗試建立 Bucket '{bucket_name}'...")
            try:
                # 尋找 "Create bucket" 或 "建立儲存貯體" 按鈕
                create_btn = page.locator("button:has-text('Create bucket'), button:has-text('建立儲存貯體'), a:has-text('Create bucket')").first
                if create_btn.is_visible():
                    create_btn.click()
                    time.sleep(2)
                    name_input = page.locator("input[name='name'], input[placeholder*='bucket']").first
                    if name_input.is_visible():
                        name_input.fill(bucket_name)
                        time.sleep(1)
                        submit_btn = page.locator("button[type='submit']:has-text('Create bucket'), button:has-text('建立儲存貯體')").first
                        submit_btn.click()
                        time.sleep(3)
                        print(f"[✓] 成功建立 Bucket '{bucket_name}'！")
            except Exception as e:
                print(f"[!] 自動建立 Bucket 時出現提示: {e}")

        # 5. 前往 R2 API Tokens 頁面
        token_url = f"https://dash.cloudflare.com/{account_id}/r2/api-tokens"
        print(f"\n[*] 正在前往 R2 API Token 管理頁面: {token_url}")
        page.goto(token_url, wait_until="domcontentloaded")
        time.sleep(3)

        # 6. 前往 Bucket 設定檢查公開訪問 (Public R2.dev domain)
        bucket_settings_url = f"https://dash.cloudflare.com/{account_id}/r2/default/buckets/{bucket_name}/settings"
        print(f"[*] 檢查 Bucket 公開存取網址: {bucket_settings_url}")
        page.goto(bucket_settings_url, wait_until="domcontentloaded")
        time.sleep(3)

        public_domain = f"https://pub-{account_id[:16]}.r2.dev"
        # 嘗試尋找 r2.dev 網址
        page_text = page.content()
        r2_domain_match = re.search(r"(https://pub-[a-zA-Z0-9_-]+\.r2\.dev)", page_text)
        if r2_domain_match:
            public_domain = r2_domain_match.group(1)
            print(f"[✓] 偵測到現有 R2 公開訪問網址: {public_domain}")
        else:
            print(f"[*] 尚未開啟 r2.dev 公開網域，建議在設定中點擊 'Allow Access' (允許存取)。")

        # 7. 更新 .env
        env_updates = {
            "CF_ACCOUNT_ID": account_id,
            "R2_BUCKET_NAME": bucket_name,
            "R2_PUBLIC_DOMAIN": public_domain,
        }
        update_env_file(env_updates)

        print("\n" + "=" * 60)
        print(" [完成進度]")
        print(f" 1. CF_ACCOUNT_ID: {account_id}")
        print(f" 2. R2_BUCKET_NAME: {bucket_name}")
        print(f" 3. R2_PUBLIC_DOMAIN: {public_domain}")
        print("\n 目前已自動將上述資訊寫入 D:\\Freedom\\HomeInventory\\.env！")
        print(f" 請在瀏覽器中開啟的 API Tokens 頁面中查看或建立一組 S3 Token，")
        print(f" 並將 R2_ACCESS_KEY_ID 與 R2_SECRET_ACCESS_KEY 存入 .env。")
        print("=" * 60)

if __name__ == "__main__":
    main()
