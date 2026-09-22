# Claude 接手：Stillwater 的非美術工作

更新：2026-09-23。工作目錄 `/Users/ianlin/IanLin/Projects/world/stream`。

## 先讀與工作邊界

使用者明確分工：Codex 完成美術；Claude 接續非美術。不要重做遊戲、改成網站、加入管理玩法，也不要恢復螯蝦。仍是 Godot 4.6.3 原生 Mac、固定側視、觀察型魚蝦溪流。起始 6 紅櫻花蝦、4 絲鰭彩虹魚、4 大理石斧頭魚。

先讀 `README.md`、`docs/ecology.md`、`docs/validation.md`、`docs/ART_DIRECTION.md`。原始生態決策在 `docs/plans/2026-09-22-self-sustaining-ecosystem.md`，以後續 v2 校準與使用者移除螯蝦的決定為準。這個目錄目前不是 Git repository；不要假設有可回滾的 commit。

保留舊 wetland 專案、build、save。原本的 crayfish 素材在專案外備份；不要找回來接到場景。不要碰使用者正式存檔來做破壞性測試。

**美術範圍已交付，保持不變**：`assets/pixel/`、`scripts/swimmer_rig.gd`、`fish_motion.gdshader`、`stream_water.gdshader`、`stream_motes.gd`、`stream_stage.gd` 的美術實作。Claude 可以修正資料介接，但若需要新的動畫/素材，寫清楚缺少的 snapshot 欄位或事件契約，不要換風格或自行生成替代素材。舊 `stream.png` 是歷史版本；正式背景是 `stream-fish-shrimp.png`。

可工作的主要檔案：`stream_world.gd`（行為/生態）、`stream_store.gd`（持久化）、`main.gd`（生命週期/互動/檢視）、`tests/`、效能工具與文件。`tools/swimmer_scene.gd` 是固定示範，不可拿影片當自主行為證據。

## 現在已完成，勿重做

- 生態 v2 六個資源池、物質帳、自然死亡、幼蝦被吃、資源/棲地限制繁殖、少量移入救援、過量幼體漂走；成年個體沒有隨機離開規則。
- 生態驗收 A 已決定：**留下的出生 + 漂走後代 ≥20**，另要求 **留下的出生 >移入**。保留各自統計，這是後代數，不是繁殖事件數。不必再次請使用者選 A/B/C。
- v1→v2 保留身分/譜系，4 隻螯蝦記 departure。容器格式字串 `stillwater-stream-1` 不代表 world schema 還是 v1。
- 72h catch-up、負時間防護、原子寫入/備份恢復、checkpoint 避免重算等已有測試，不要重寫。
- 0.4.1 增加跨區探索、個體速度、彎曲游線；使用者反映看起來只在小範圍來回，不可退回舊巡邏。motion RNG 已持久化，和生態 RNG 分開。
- 0.5.0 是美術整合版本：背景、環境動態、魚轉身弧線與進食細節。沒有改生態率或存檔 schema。

詳細結果以 `docs/validation.md` 的版本標記為準：104 core / 103 rig 測試、三組180天、一组365天已有證據。0.4.0 曾通過31分鐘前景及真正Cmd-H/Cmd-M低於1% CPU。**不能把0.4.0結果當0.5.0完整验收**；0.5.0新增shader需重測。11種子掃描是之前Claude回報，這邊沒有重跑全部11種。

## 按順序執行

### 1. 先建立正式包的安全持久化測試入口

現有 `--qa` 每次建立新世界，`_save()`不寫正式世界，所以它只能驗證畫面/CPU，**不能證明正式退出重開的持久化流程**。

加入明確隔離的 persistence-QA 模式或可重複測試 fixture，讓它走與正式版相同的 load/save/catch-up/close 通路，但只存到專用測試子目錄。不要在正常啟動時自動選到測試世界；不要改 `preferences.cfg` 指向測試路徑。記錄實際使用路徑與模式。入口需覆蓋主視窗關閉、Cmd-Q，以及背景時關閉；程式退出後不得留進程。

驗收：啟動→修改測試世界→正常退出→重開，逐個比較仍存活個體 id/name/parent，以及資源、events、RNG、wall checkpoint。原使用者 `stream.world`、`.bak`、`preferences.cfg` 前後雜湊一致。已有 `_save` / `load_or_create` 可重用，不要分叉另一套持久化格式。

### 2. 補齊生命週期整合測試

在隔離模式下測幾分鐘、72h、幾週（只能補算72h）、負 elapsed、損壞 primary、損壞 primary+backup、在 catch-up 提交前中斷、提交後立即重開。故障注入只能作用於測試檔。

檢查一個已觀察到的風險：隱藏時每分鐘 `advance_offline`，恢復時 `_set_away`只拿最後剩餘那一小段；它又忽略<120秒，可能使長時間隱藏後沒有整段摘要。應累積這次 absence 的 seconds/events，再顯示一次摘要，不能重新套用已計算時間。同步驗證暫停、背景儲存與 clock jump 不會重複 advance。先寫能失敗的整合測試再修。

實機 sleep/wake 仍未測。不要擅自把使用者整台 Mac 強制睡眠或改能源設定。先把隔離測試準備好，讓使用者在方便時自然睡眠/喚醒，留下前後 timestamp、是否一次補算及摘要。無法實測就標未測，不要用單純暫停進程冒充硬體睡眠。

### 3. 驗證新移動對 live 生態的影響

跑 `test_roaming.gd`，並補上長一點的live/加速live批次。保持夜間活動差異，不要為了畫面熱鬧修改日夜規則。

0.4.1改變位置/接觸頻率，可能影響近距離捕食。offline種子結果不代表live完全相同。檢查：幼蝦庇護、被吃的size/hunger/cover條件、脫殼保護、物種深度範圍、地面步行與游泳落地不跳躍、個體不黏邊、不高頻抖動。禁止用隨機刪除個體掩蓋問題。

輸出每次run的種子、模式、模擬時間、出生/漂走/移入/死亡原因、每種缺席天數、12–18比例、守恆誤差。維持原生態驗收；若真的要改參數，記錄理由及前後結果，不要只是把失敗門檻放寬。

### 4. 將自然事件與呈現對接

目前固定示範錄影只測 rig。建立可重現 scenario，使用真正的 simulation 狀態與事件觸發躲藏、脫殼、幼蝦被吃等流程。避免「先讓角色消失，再由UI猜發生什麼」。snapshot/event契約需提供id、活動、位置、事件原因及必要時的對象id；只增加可選/有預設欄位並驗證舊存檔。

presentation只能讀取；選取、zoom、viewing light不可消耗生態 RNG 或改變結果。捕食維持非血腥。若少了演出，列成有明確trigger/完成狀態的美術需求給Codex，Claude不要自行改素材。

### 5. 最新正式包效能驗收與交付

完成非美術修改後才跑完整30分鐘，避免每次小改都重跑。測14隻起始cast，另測24隻防禦上限fixture（不修改正式棲地上限）。紀錄Godot版本、build版本、CPU、RSS、實際drawn frames、focus/hidden秒數、thermal。CPU以100%=一核心；RSS注意MiB與MB。前景平均CPU<15%、隱藏<1%、RSS<350MB、30FPS、72h補算<2s。

工具 `tools/foreground_acceptance.py` 預設31分鐘，暖機後需要至少1800秒真前景；`foreground_30_minute_eligible`必须為true。測試期間不要同時export/record/跑months。最新美術若超標，先減少裝飾效果，保留角色可讀性；不要降低simulation正確性。

`sample_lifecycle.py`早期可能讀到上一輪qa-progress，請以檔案mtime或run_id隔離，報告不能混用。已有失敗最小化嘗試的檔案保留，不要把它算通過。macOS讀取AX可能把視窗帶回，因此隱藏CPU取樣時不要一直讀視窗。

輸出新的驗證報告與版本化正式app。簽章是本機ad-hoc，不是Apple notarization。記錄失敗/未测項，不可只寫「完成」。不需要購買憑證、上架或新增背景服務。

## 指令

在 `stream/` 下執行：

```sh
/opt/homebrew/bin/godot --headless --path . --script tests/test_world.gd
/opt/homebrew/bin/godot --headless --path . --script tests/test_swimmers.gd
/opt/homebrew/bin/godot --headless --path . --script tests/test_roaming.gd
/opt/homebrew/bin/godot --headless --path . --script tests/long_run.gd
/opt/homebrew/bin/godot --headless --path . --export-release macOS "$PWD/builds/Stillwater Stream.app"
codesign --verify --deep --strict 'builds/Stillwater Stream.app'
python3 tools/foreground_acceptance.py
```

`artifacts/.gdignore`避免Godot匯入上千張診斷PNG。不要刪掉它。正式export已排除tests/artifacts/docs/tools，勿打包錄影。

## 完成條件

安全持久化真實退出/重開通過、故障恢復與時間邊界有證據、新移動的live生態已驗證、最新build性能通過、非美術缺陷修完。硬體sleep/wake若缺使用者操作需明確保留未驗證。用繁體中文交付簡短結果、app位置、報告位置、remaining事項；不要要求使用者再次決定已經定案的風格/物種/出生標準。
