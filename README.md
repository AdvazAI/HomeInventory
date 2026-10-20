# HomeInventory (家庭庫存管理系統)

家庭庫存管理系統是一套專為家庭設計的高效物品與空間管理應用。透過極致壓縮的拍照技術、QR Code 標籤掃描、Brother 熱感應印表機連線、Google Gemini 3.5 Flash Lite 向量語義搜尋，以及借還狀態（Check-in / Check-out）歷程追蹤，徹底解決家中物品「隨手放、找不到、重複買」的痛點。

---

## 系統架構與技術選型

```
[Flutter Mobile App (iOS / Android)]
       │
       │ HTTPS / REST API (homeinv.advaz.au)
       ▼
[Cloudflare CDN & Proxy]
       │
       │ Origin Rule & SNI Rewrite
       ▼
[Google Cloud Run (Python FastAPI)]
       │
       ├─► [Supabase PostgreSQL (Sydney ap-southeast-2)]
       │     └─ Schema: home_inventory (完全隔離)
       │
       ├─► [Supabase Storage / Cloudflare R2]
       │     └─ 450px / 3~5KB 超極限等比壓縮圖檔
       │
       ├─► [Google Gemini 3.5 Flash Lite]
       │     ├─ gemini-embedding-001 (3072 維度向量編碼)
       │     └─ gemini-3.5-flash-lite (同義詞與模糊關聯極速聯想)
       │
       └─► [Brother QL-700 (BrotherLabelPtr)]
             └─ Win32 GDI 直接驅動，2cm x 2cm QR Code 標籤列印
```

---

## 目錄結構

```
HomeInventory/
├── backend/                # Python FastAPI 後端服務
│   ├── app/
│   │   ├── config.py       # 環境變數與配置中心
│   │   ├── database.py     # SQLAlchemy 2.0 (Supabase home_inventory Schema)
│   │   ├── models.py       # 資料表模型
│   │   ├── printing.py     # Brother QL-700 印表機驅動
│   │   ├── schemas.py      # Pydantic v2 資料驗證模型
│   │   ├── search.py       # Gemini 3.5 Flash Lite 向量與語義擴展搜尋
│   │   ├── storage.py      # 雲端圖床儲存介面
│   │   └── routers/        # API 路由 (物品、位置、借還、標籤列印)
│   ├── Dockerfile          # Cloud Run 生產容器建置檔
│   └── requirements.txt    # 後端套件清單
│
├── frontend/               # Flutter 跨平台行動應用
│   ├── lib/
│   │   ├── models/         # 前端資料模型
│   │   ├── pages/          # UI 介面 (掃描器、位置瀏覽、物品管理、印表機列印)
│   │   ├── providers/      # Riverpod 狀態管理
│   │   ├── services/       # Dio API 網路連線服務
│   │   └── utils/          # 圖片超高壓縮處理 (長邊 450px, 3~5KB)
│   └── pubspec.yaml        # Flutter 套件管理
│
├── scripts/                # 自動化運維與輔助工具
│   ├── deploy_cloud_run.ps1       # Google Cloud Run 一鍵打包與部署
│   ├── open_headed_browser.ps1    # 打破 Windows 桌面隔離之有頭瀏覽器工具
│   ├── open_headed_browser.py     # Win32 原生有頭瀏覽器啟動腳本
│   └── setup_supabase_bucket.py   # Supabase Storage 儲存桶建立
│
├── .env.example            # 環境變數範本檔
├── .gitignore              # 安全防護忽略清單 (嚴格排除 .env 與私鑰)
└── README.md
```

---

## 核心功能特色

1. **極致圖片壓縮機制**：
   - 上傳前前端自動裁切，以長邊 450 像素等比例縮放。
   - 檔案壓縮至 3KB ~ 5KB，大幅節省儲存空間與行動傳輸量。
   - 拍照介面提供勾選框，使用者可隨時取消勾選以保留高畫質原圖。
2. **QR Code 標籤與 Brother QL-700 直印**：
   - QR Code 資訊嚴格限制在 80 字元以內，印出尺寸至少 2cm × 2cm，保證手機瞬間秒讀對焦。
   - 支援免預覽直接發送至 BrotherLabelPtr 列印。
3. **借還登記與智能防誤觸 (Debounce)**：
   - 5 秒防重複按壓機制，自動覆蓋前一次操作。
   - 寄生式活動紀錄自動清理，每次操作時自動清除超過 1 個月的歷史日誌，資料庫永保輕巧高效。
4. **尋找遺失物 (Lost Item Trace)**：
   - 桌面發現未知 QR 碼物品，一掃即知「最後由哪位家人從哪個櫃子借出」，並顯示歸位導航。
5. **Gemini 3.5 Flash Lite 向量搜尋**：
   - 結合語義向量與同義詞智慧聯想，即使忘記確切名稱也能快速找到。
