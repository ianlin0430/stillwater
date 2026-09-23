# Codex 接手：Stillwater 的前端工作計畫

更新：2026-09-23。工作目錄 `/Users/ianlin/IanLin/Projects/world/stream`。依序執行；每一步的驗收沒過，不進下一步。

## 先讀與工作邊界

使用者分工：**Codex 負責前端與美術，Claude 負責 backend 與其他所有工作**（生態、存檔、生命週期、CI、效能驗收、打包）。

先讀：
- `docs/CODEX_FRONTEND_HANDOFF.md`：**規格**（事件演出表、蝦精緻化細節、效能底線）。本計畫只講順序和驗收，規格以它為準。
- `docs/BACKEND_SNAPSHOT_EVENTS.md`：backend 實際提供的欄位與事件（含 `tint`、`brood_until`、`berried`、`brood_lost`，commit `3ffccee`）。
- `docs/ART_DIRECTION.md`：沿用 C / Soft Pixel。

已定案，不要再問使用者：Soft Pixel 風格、只有魚和蝦、**沒有捕食**（「幼蝦被吃」演出取消）、蝦尺寸不放大、母蝦抱卵約 5 天、個體 `tint` 會遺傳、蝦精緻化先給使用者看比較圖。

**可以改**：`stream_stage.gd`、`stream_habitat.gd`、`stream_motes.gd`、`swimmer_rig.gd`、`*.gdshader`、`assets/`、前端測試（`tests/test_frontend.gd`）、展示場景與 `tools/` 下的前端工具、`FRONTEND_BACKEND_CONTRACT.md`。
**局部改**：`main.gd` 只動 `_scene_input` 和操作提示。
**不要改**：`stream_world.gd`、`stream_store.gd`、`absence.gd`、`persist_qa.gd`、生態測試、`.github/`。需要 backend 欄位或事件時，寫明要什麼交給 Claude，不要在前端猜或自己算生態。

**git**：repo 在 GitHub（private `ianlin0430/stillwater`，branch `main`）。Claude 也在同一個工作目錄 commit：
- 只 `git add` 自己的檔案路徑，不要用 `git add -A` 或 `git add .`。
- commit 前先看 `git diff --cached --stat`。
- 一個 commit 只做一件事。

**耗電**：使用者在意耗電。不要在本機跑長時間模擬、多種子批次或長錄影；短的 headless 測試和一兩分鐘的 QA 可以。

## 按順序執行

### 0. 把目前未 commit 的前端收好

工作目錄裡已經有你還沒 commit 的改動：`main.gd`（拖曳撥水、R 水紋、提示文字）、`stream_stage.gd`、`stream_habitat.gd(.uid)`、`test_frontend.gd(.uid)`、`FRONTEND_BACKEND_CONTRACT.md`。

- 先確認它們能跟 `main` 上最新的 backend 一起跑：`test_frontend` 和 `test_presentation` 都要通過。
- 修正 `FRONTEND_BACKEND_CONTRACT.md`：
  - `stream_absence.gd` 改成實際檔名 `scripts/absence.gd`。
  - 引用 `BACKEND_SNAPSHOT_EVENTS.md`。
  - 刪掉捕食演出的描述。
- 分成有意義的 commit 送出。

**驗收**：
- `git status` 裡沒有你的未 commit 檔案。
- `test_frontend` 通過。
- `test_presentation` 通過（它負責證明前端不改動生態）。

### 1. 接上事件游標、延遲移除、重定位

照 handoff §1 做：
- 事件游標：第一次不重播歷史；只演出 `live==true` 的事件；換世界或重新載入時只重設游標。
- 動物消失時：有 `death` 事件就先在事件位置演完再移除，外觀從 `archive` 查。
- `relocated_at` 比上一份 snapshot 的時間新時，不畫長尾流。

在 `tests/test_frontend.gd` 補上會先失敗的測試，再實作：
1. 載入已有 events 的世界時，第一個 snapshot 不演出任何事件。
2. 只有 `live==true` 的事件會觸發演出；離線補算產生的事件不會。
3. 游標後退（換世界或重新載入）時不重播。
4. 有 `death` 事件的個體不會立刻消失，演完才移除；沒有事件卻消失的個體照舊移除（防呆）。
5. 重定位的那一段不產生長尾流。
6. 前端處理前後，`export_state()` 的位元組和兩組 RNG 都不變。

**驗收**：上面 6 項加上既有檢查全部通過；`test_presentation` 通過。

### 2. 自然事件演出

照 handoff §2 的表格做：出生、自然死亡、移入、幼體漂走、脫殼加空殼、抱卵卵團。都要非血腥，都不能改變動物軌跡或生態。
- `death` 帶 `brood_lost:true` 時，卵團跟著母蝦一起淡出就好，不另外做演出。
- 暫停時 delta=0，演出要凍結；隱藏時停止更新。

**證據要用真的模擬觸發**：做一個可重現的 scenario 工具（放在 `tools/`，例如 `tools/event_review.gd`）。它用固定種子建立真正的 `StreamWorld`，推進到自然發生出生、脫殼、抱卵、死亡、漂走、移入，並在事件發生時截圖。**不要先把角色藏起來、再由 UI 假裝發生了事件**，也不要用 `tools/swimmer_scene.gd` 的固定示範當證據。scenario 的模擬時間要短，能用 `advance_offline` 快轉到事件附近、再用 `advance_live` 看演出就這麼做，避免長時間跑。

**驗收**：
- `artifacts/event-review/` 裡每種事件至少一組截圖（事件前、演出中、完成後），附一份 `README.md` 列出種子、模擬時間、事件 id。
- 補上演出的狀態測試：開始、進行中、完成；暫停時凍結；演出數量有上限，不會一直累積。

### 3. 蝦精緻化（分兩段，中間要使用者點頭）

規格見 handoff §3（3a 質感顏色、3b 解剖、3c 動作、3d 外觀反映身份與狀態）。尺寸和比例不變。

**3-1 先做素材與比較圖，停下來給使用者看**
- 產出新的蝦素材或 rig 繪製方式，保持 Soft Pixel。
- 把素材來源與 prompt 記在 `docs/`，沿用 `art-050-provenance.md` 的做法。
- 前後對照圖放在 `artifacts/shrimp-review/`：
  - 一般視角與 1.65× 各一組。
  - 公蝦、母蝦、幼蝦（剛出生、半成熟）、抱卵母蝦、剛脫殼的蝦（含空殼）各一張。
  - tint 低、中、高三隻並排。
  - 幾秒鐘的行走、游泳、覓食、轉身短片。
- 截圖要用真正的 rig 和真正的 snapshot 欄位（`sex`、`age`、`tint`、`molting_until`、`brood_until`），不要做另一套只給截圖用的畫法。

**→ 在這裡停下，把比較圖交給使用者。使用者說好才進 3-2。** 不滿意就在素材階段改。

**3-2 整合進正式 rig**
- 把通過的素材接進 `swimmer_rig.gd` 和 shader。
- 游泳足擺動、步足交替、觸鬚延遲都要由真的移動速度與活動狀態驅動，不要用固定循環假裝。
- 缺 `tint` 視為 0.6；魚沒有 `tint` 欄位。
- 更新 `tests/test_swimmers.gd` 的相關檢查。原有 103 項若有因為設計改變而失效的，說明原因再改，不要直接刪掉。

**驗收**：
- 使用者已核可比較圖。
- `test_swimmers`、`test_frontend`、`test_presentation` 都通過。
- 在正式包的一般視角和 1.65× 下，看得出公蝦／母蝦／幼蝦／抱卵的差異，蝦腳和沙地有接觸、沒有漂浮或穿地。

### 4. 效能自查（短跑，不是正式驗收）

正式的 30 分鐘驗收由 Claude 在你交付後跑，只跑一次。你這邊只做短的自查，及早發現明顯超標：
- 用 `-- --qa --duration=120` 跑一次打包版，視窗保持在前景，看 `qa-performance.json` 的 frame 數據，再用 `tools/sample_process.py` 取樣 CPU/RSS。
- 目標：前景平均 CPU <15%（一核心 = 100%）、RSS <350MB、30FPS。
- 若超標，照 handoff §4：先減裝飾效果，不犧牲蝦的可讀性，不改 simulation。
- 測試期間不要同時 export、錄影或跑其他模擬。

**驗收**：短跑數字記在交付報告裡，並註明「非正式 30 分鐘驗收」。

### 5. 交付

最後一個 commit 之後，回報以下內容：
- 每一步標「已完成／未完成／需要 backend」。
- 比較圖和事件截圖的位置；使用者核可蝦的時間點。
- 所有測試的實際輸出（檢查數、失敗數）。
- 短跑效能數字。
- commit hash 清單。
- 需要 Claude 補的 backend 欄位或事件，寫清楚要什麼、用途是什麼。

不要只寫「完成」。沒做到的、失敗的、未驗證的，照實列出來。交付後通知 Claude 跑正式 30 分鐘效能驗收與版本化打包。

## 指令

在 `stream/` 下執行：

```sh
/opt/homebrew/bin/godot --headless --path . --script tests/test_frontend.gd
/opt/homebrew/bin/godot --headless --path . --script tests/test_presentation.gd
/opt/homebrew/bin/godot --headless --path . --script tests/test_swimmers.gd
/opt/homebrew/bin/godot --headless --path . --export-release macOS "$PWD/builds/Stillwater Stream.app"
codesign --verify --deep --strict 'builds/Stillwater Stream.app'
```

`artifacts/` 已被 gitignore，`artifacts/.gdignore` 不要刪。正式 export 已排除 tests/artifacts/docs/tools，不要把錄影打包進去。

## 完成條件

- 前端改動全部 commit。
- 事件游標、延遲移除、重定位都有測試。
- 每種自然事件都有用真實模擬觸發的截圖。
- 蝦精緻化經使用者核可，並已整合。
- 短跑效能沒有明顯超標。
- 前端測試全部通過，`test_presentation` 證明前端沒有改動生態。
