#!/usr/bin/env python3
"""
Cloudflare R2 Bucket 自動查詢與建置輔助腳本
用途: 讀取 .env 中的 Cloudflare 憑證，自動查詢現有帳號、R2 Bucket，或自動建立 Bucket 並驗證連線。
"""

import os
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path
from dotenv import load_dotenv

# 載入 .env
env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

CF_ACCOUNT_ID = os.getenv("CF_ACCOUNT_ID", "").strip()
CF_API_TOKEN = os.getenv("CF_API_TOKEN", "").strip()
CF_API_EMAIL = os.getenv("CF_API_EMAIL", "").strip()
CF_GLOBAL_API_KEY = os.getenv("CF_GLOBAL_API_KEY", "").strip()
R2_BUCKET_NAME = os.getenv("R2_BUCKET_NAME", "home-inventory-photos").strip()
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID", "").strip()
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY", "").strip()

def get_headers():
    if CF_API_TOKEN:
        return {
            "Authorization": f"Bearer {CF_API_TOKEN}",
            "Content-Type": "application/json"
        }
    elif CF_API_EMAIL and CF_GLOBAL_API_KEY:
        return {
            "X-Auth-Email": CF_API_EMAIL,
            "X-Auth-Key": CF_GLOBAL_API_KEY,
            "Content-Type": "application/json"
        }
    return None

def cf_api_request(method: str, path: str, payload: dict = None):
    url = f"https://api.cloudflare.com/client/v4{path}"
    headers = get_headers()
    if not headers:
        raise ValueError("缺少 Cloudflare 驗證資訊 (需填寫 CF_API_TOKEN 或 CF_API_EMAIL + CF_GLOBAL_API_KEY)")
    
    data = json.dumps(payload).encode("utf-8") if payload else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            return json.loads(err_body)
        except Exception:
            return {"success": False, "errors": [{"message": f"HTTP {e.code}: {err_body}"}]}
    except Exception as e:
        return {"success": False, "errors": [{"message": str(e)}]}

def main():
    print("=" * 60)
    print(" Cloudflare R2 自動檢查與配置工具")
    print("=" * 60)
    
    headers = get_headers()
    if not headers:
        print("[!] 尚未在 .env 設定 Cloudflare 憑證。")
        print("    請在 D:/Freedom/HomeInventory/.env 中填入：")
        print("    - CF_API_TOKEN (推薦)")
        print("    或")
        print("    - CF_API_EMAIL + CF_GLOBAL_API_KEY")
        print("=" * 60)
        sys.exit(1)
        
    global CF_ACCOUNT_ID
    # 1. 若無 ACCOUNT_ID，嘗試自動查詢帳號列表
    if not CF_ACCOUNT_ID or CF_ACCOUNT_ID == "your_cloudflare_account_id_here":
        print("[*] 正在向 Cloudflare 查詢使用者帳戶清單...")
        res = cf_api_request("GET", "/accounts")
        if res.get("success") and res.get("result"):
            accounts = res["result"]
            print(f"[✓] 成功取得 {len(accounts)} 個帳戶:")
            for idx, acc in enumerate(accounts):
                print(f"    [{idx + 1}] 名稱: {acc.get('name')} | ID: {acc.get('id')}")
            CF_ACCOUNT_ID = accounts[0]["id"]
            print(f"[*] 自動選取第一個帳戶: {CF_ACCOUNT_ID}")
        else:
            errors = res.get("errors", [])
            print(f"[x] 無法自動取得帳戶列表: {errors}")
            print("    請直接手動在 .env 中填寫 CF_ACCOUNT_ID。")
            sys.exit(1)
            
    # 2. 查詢現有的 R2 Buckets
    print(f"\n[*] 正在檢查帳戶 {CF_ACCOUNT_ID} 下的 R2 Buckets...")
    res = cf_api_request("GET", f"/accounts/{CF_ACCOUNT_ID}/r2/buckets")
    if not res.get("success"):
        errors = res.get("errors", [])
        print(f"[x] 查詢 R2 Buckets 失敗: {errors}")
        print("    注意: 您的 API Token 必須具有 R2 Read & Write 權限，且帳戶需已在 Cloudflare 啟用 R2 服務。")
        sys.exit(1)
        
    buckets = res.get("result", {}).get("buckets", [])
    bucket_names = [b.get("name") for b in buckets]
    print(f"[✓] 目前現有 R2 Buckets ({len(bucket_names)}): {bucket_names}")
    
    # 3. 檢查目標 Bucket 是否存在，若無則建立
    if R2_BUCKET_NAME in bucket_names:
        print(f"[✓] 目標 Bucket '{R2_BUCKET_NAME}' 已經存在！")
    else:
        print(f"[*] 目標 Bucket '{R2_BUCKET_NAME}' 不存在，正在為您自動建立...")
        create_res = cf_api_request("POST", f"/accounts/{CF_ACCOUNT_ID}/r2/buckets", {"name": R2_BUCKET_NAME})
        if create_res.get("success"):
            print(f"[✓] 成功建立 R2 Bucket: '{R2_BUCKET_NAME}'！")
        else:
            print(f"[x] 建立 Bucket 失敗: {create_res.get('errors')}")
            sys.exit(1)

    print("\n" + "=" * 60)
    print(" [提示] R2 S3 相容金鑰設定：")
    print(f" S3 Endpoint: https://{CF_ACCOUNT_ID}.r2.cloudflarestorage.com")
    print(f" Bucket Name: {R2_BUCKET_NAME}")
    print(" 請確保在 .env 中也已填入 R2_ACCESS_KEY_ID 與 R2_SECRET_ACCESS_KEY")
    print("=" * 60)

if __name__ == "__main__":
    main()
