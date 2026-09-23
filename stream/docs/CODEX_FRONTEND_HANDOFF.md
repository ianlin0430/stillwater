# 給 Codex：前端待辦（2026-09-23）

> **最新（2026-09-23）：使用者決定拿掉蝦。本檔 §3 蝦精緻化整節、§2 的脫殼與抱卵兩列都已取消。** 順序和最新範圍以 `CODEX_FRONTEND_PLAN.md` 為準。

使用者分工：**Codex 負責前端與美術，Claude 負責 backend 與其他所有工作**。本檔是目前全部的前端待辦。backend 欄位細節以 `BACKEND_SNAPSHOT_EVENTS.md` 為準；你的 `FRONTEND_BACKEND_CONTRACT.md` 仍是你的檔案。

## 已定案，不要再問使用者

- 風格維持 C / Soft Pixel，不改寫實，不恢復螯蝦。
- **捕食已整個移除**（使用者 2026-09-23 決定）：沒有任何動物吃別的動物。「幼蝦被吃」演出**取消**。death 事件的 `cause` 現在只有 `"starvation"`、`"old age"`；舊存檔的歷史事件可能還有 `"predation"` / `feeding`，只進日誌、不播。
- 蝦受驚短衝 `Retreating` 保留（隨機行為，不是捕食）。
- 最終 30 分鐘效能驗收與正式打包**等你這批前端 commit 後**才由 Claude 跑，只跑一次。

## 0. 先做：把目前未 commit 的前端 commit 起來

你在同一個工作目錄裡有未 commit 的 `scripts/main.gd`、`scripts/stream_stage.gd`、`scripts/stream_habitat.gd(.uid)`、`tests/test_frontend.gd(.uid)`、`docs/FRONTEND_BACKEND_CONTRACT.md`。repo 已在 GitHub（private `ianlin0430/stillwater`，branch `main`）。請：

- 做完一段就 commit，只 `git add` 自己的檔案路徑（Claude 也在同一個 tree commit，別用 `git add -A/.`）。
- `main.gd` 是共用接線檔：只改 `_scene_input` 與操作提示；不要動 persist-QA（`--persist-qa`、`PersistQA`）、absence（`scripts/absence.gd`）與存檔程式。
- 契約裡寫的 `stream_absence.gd` 實際檔名是 `scripts/absence.gd`，請更正，並引用 `docs/BACKEND_SNAPSHOT_EVENTS.md`。

## 1. 接上 backend 事件與速度（backend 已完成，commit `d54de6f`）

1. **事件游標**（`stream_stage.gd` 的 `apply_snapshot`）：第一次呼叫設 `cursor = next_event-1`，不重播歷史。之後每次用 `StreamWorld.events_after(value.events, cursor)` 取新事件，只演出 `live==true` 的，再更新 cursor。若 `next_event-1 < cursor`（換世界/重新載入）只重設 cursor、不播。
2. **動物消失**：目前看到動物不在 `animals` 就直接 `queue_free`。改成：有對應 `death` 事件時，先在事件 `x/y` 播完演出再移除；外觀資料（species、age、sex、tint）從 `archive` 用 id 查。
3. **尾流**：`a.get("relocated_at",-1) > 上一份 snapshot 的 elapsed` 時是瞬間重定位，不畫長尾流、直接跳位。`vx/vy` 缺少視為 0。
4. 活動名稱沒有新增或改名。`Sheltering` 雖在 stage 列著，但 backend 目前不會設。

## 2. 自然事件演出（美術需求）

每項都要非血腥、不改變動物軌跡或生態，演出期間 snapshot 仍是唯一真相。

| 事件 | 觸發 | 演出 | 完成狀態 |
|---|---|---|---|
| 出生 | `birth` 且 `live` | 幼體在親代旁約 1.5 秒淡入 | 不透明度回到 1 |
| 自然死亡 | `death`，cause 為 old age / starvation | 在事件位置約 2 秒淡出並緩緩沉到底 | rig 移除 |
| 移入 | `arrival` 且 `live`（x=130 或 1150） | 從畫面邊緣淡入 | 正常游動 |
| 幼體漂走 | `dispersal` 且 `live`（沒有對應個體） | 從親代位置出現小幼體剪影，往下游漂並淡出 | 約 4 秒後離開畫面 |
| 脫殼 | `molt` 且 `live` | 蝦在 `until` 前變淡；**原地留下一個半透明空殼** | 空殼在 `until` 後淡出 |
| 抱卵（新，見 §3） | `berried` 且 `live` | 母蝦腹下出現卵團 | 持續到孵化；孵化時接 `birth` |

## 3. 蝦精緻化（使用者 2026-09-23 逐題確認）

目前的蝦零件是均勻不透明紅色，在一般視角約 60–70 px 寬，看起來是一團紅，和魚（鱗片、明暗、鰭條）落差明顯。要追上魚的精緻度。

**尺寸與比例不變**：蝦與魚的相對大小已接近真實物種，不放大；近看靠既有 1.65× zoom。

### 3a. 質感與顏色
- 身體**半透明**，布滿**紅色色素點**，不是一整片平塗紅；有明暗層次（背部較深、腹側較透）。
- 可以透過身體隱約看到底下的背景或沙地。
- 保持 Soft Pixel：清楚輪廓、柔和色塊、nearest sampling，不用模糊濾鏡。

### 3b. 解剖細節
- **兩對長觸鬚**（長的一對約體長 1–1.5 倍）、額角（rostrum）。
- 細長的**步足**，腹部下方一排**游泳足**（pleopods）。
- 腹節分明、尾扇。
- 參考：紅櫻花蝦 *Neocaridina davidi*。

### 3c. 動作
- 游泳足**持續小幅擺動**（游泳時加快）。
- 步足**交替行走**，腳底貼地，不滑步、不跳。
- 觸鬚隨水流與轉身**延遲飄動**。
- 覓食時前足輪流抓取送到口部。
- 不加無意義的 idle 抖動。

### 3d. 外觀反映身份與狀態
backend 已在 snapshot 提供（commit `3ffccee`，細節見 `BACKEND_SNAPSHOT_EVENTS.md`；抱卵中死亡的 `death` 事件會帶 `brood_lost:true`）：

| 欄位 | 來源 | 前端呈現 |
|---|---|---|
| `sex` | 既有 | 母蝦較大、紅得濃；公蝦較小、偏透明淡紅 |
| `age` 與物種 `mature` | 既有 | 幼蝦**幾乎透明**，隨年齡漸漸變紅，成熟時達到個體的 `tint` |
| `tint` | **新**，0–1 浮點，個體固定 | 紅色深淡與色點密度。幼蝦大致繼承母蝦、加少量隨機，所以母子看得出相像。缺少時視為 0.6 |
| `molting_until` | 既有 | 脫殼期間變淡（配合 §2 空殼） |
| `brood_until` | **新**，模擬秒；只有抱卵中的母蝦有 | 腹下黃綠色卵團；接近孵化時可略變深 |

抱卵：母蝦符合繁殖條件後進入約 5 天的抱卵期（`berried` 事件），期滿才孵出幼蝦（`birth` 事件，親代為該母蝦）。畫面上看到抱卵母蝦，就代表幾天後真的會有小蝦出生。

### 3e. 驗收：先看比較圖，使用者說好才接進正式版
先交一組**前後對照**給使用者看，再接進正式 rig：
- 一般視角與 1.65× 近看各一組。
- 公蝦、母蝦、幼蝦、抱卵母蝦、剛脫殼的蝦各一張。
- 幾秒的行走、游泳、覓食短片。
- 放在 `artifacts/shrimp-review/`（已被 gitignore），並附一行說明素材來源與 prompt（沿用 `art-050-provenance.md` 的做法）。

使用者不滿意就在素材階段改，不要先整合完再改。`tools/swimmer_scene.gd` 的固定示範可用來錄短片，但不能當自主行為的證據。

## 4. 效能與測試

- 最終驗收標準（Claude 跑）：前景平均 CPU < 15%（一核心 = 100%）、隱藏 < 1%、RSS < 350 MB、30 FPS。若蝦變精緻後超標，**先減少裝飾效果，不犧牲蝦本身的可讀性**，也不要降低 simulation 正確性。
- 暫停時 delta=0 凍結所有演出；隱藏時照既有 renderer suspension 停止更新。
- 前端不得消耗 `rng` / `motion_rng` 或改變 `export_state()`（`tests/test_presentation.gd` 會擋）。你的 `tests/test_frontend.gd` 請持續保持通過。
- 雲端 CI（`.github/workflows/ecology-batch.yml`）會跑 `test_world`、`test_swimmers`、`test_roaming`、`test_lifecycle`、`test_persist_qa`、`test_presentation`；若你新增前端測試想進 CI，告訴 Claude。
- 不要在本機跑長時間模擬（使用者在意耗電）。

## 完成時回報

每項標「已完成／未完成／需要 backend」，附比較圖位置、commit hash、`test_frontend` 結果。缺 backend 欄位或事件時，寫清楚要什麼，不要在前端猜。
