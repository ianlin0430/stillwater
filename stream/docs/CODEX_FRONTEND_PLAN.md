# Codex 接手：Stillwater 的前端工作計畫

> **最新需求（2026-09-23）：「不要蝦子 魚就好」。** 蝦的美術迭代、核可與正式整合均取消。以 [FISH_ONLY_CLAUDE_HANDOFF.md](FISH_ONLY_CLAUDE_HANDOFF.md) 為最新分工；以下蝦相關段落只保留為歷史，不能繼續照做。保留魚類工作與環境互動。

更新：2026-09-23。工作目錄 `/Users/ianlin/IanLin/Projects/world/stream`。依序執行；每一步的驗收沒過，不進下一步。

> **2026-09-23 最新：使用者決定整個拿掉紅櫻花蝦。** 之後斧頭魚也拿掉了：目前池子裡只有絲鰭彩虹魚（上限 8、開局 6）和花園鰻（上限 4、開局 2），族群目標 8–12 隻，硬上限 24 不變。這是暫定名單，使用者要等你畫好新物種再選（候選：斑馬螺、火焰燈魚、熊貓鼠魚、點點缸玉魚等，Claude 建議斑馬螺＋火焰燈魚）。舊存檔的斧頭魚也在讀檔時記成離開。舊存檔裡的蝦在讀檔時記成「離開池子」，歷史和日誌保留。**所有蝦相關工作都取消**：§3 整節、§2 的抱卵卵團與脫殼空殼、蝦的素材與比較圖。做到一半的蝦素材不要整合，可以刪掉或留在 artifacts。backend 由 Claude 同步修改，完成後以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。

> **2026-09-24 使用者核可（經 Claude 確認）**：`artifacts/reef-review/cast-v2.png` 的五個物種**全部核可**，`reef-background-v1.png`／`background-normal.png` 的海底背景**核可**。**黃金吊**（*Zebrasoma flavescens*）加入名單。最終名單：花園鰻 `garden_eel`、割草機鳚 `lawnmower_blenny`、黃金吊 `yellow_tang`、藍綠光鰓魚 `green_chromis`、紫雷達 `purple_firefish`（*Nemateleotris decora*，取代紅雷達）。Claude 正在把 backend 從紅雷達改成紫雷達並加入黃金吊；完成後欄位以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。你可以開始做正式素材與 rig：比例照真實體型（黃金吊最大的一種魚，光鰓魚最小），做完照 §3.7 再給使用者看動態比較。
> **2026-09-24 最新：改成海水礁岩池，app 改名 Stillwater Reef。** 名單定案：**花園鰻**（保留）、**割草機鳚** *Salarias fasciatus*（在石頭和沙底刮藻）、**紅雷達** *Nemateleotris magnifica*（懸停在自己的沙洞上方，受驚鑽洞）、**藍綠光鰓魚** *Chromis viridis*（中層成群游）。絲鰭彩虹魚也拿掉了（現有素材不再使用）。使用者開一個全新的世界，舊的溪流存檔保留。詳細的新工作見 §3.7；各物種的欄位與活動名稱以 `BACKEND_SNAPSHOT_EVENTS.md` 為準（Claude 正在做 backend）。

## 先讀與工作邊界

使用者分工：**Codex 負責前端與美術，Claude 負責 backend 與其他所有工作**（生態、存檔、生命週期、CI、效能驗收、打包）。

先讀：
- `docs/CODEX_FRONTEND_HANDOFF.md`：**規格**（事件演出表、效能底線；其中蝦的部分已取消）。本計畫只講順序和驗收，規格以它為準。
- `docs/BACKEND_SNAPSHOT_EVENTS.md`：backend 實際提供的欄位與事件（含 `tint`、`brood_until`、`berried`、`brood_lost`，commit `3ffccee`）。
- `docs/ART_DIRECTION.md`：沿用 C / Soft Pixel。

已定案，不要再問使用者：Soft Pixel 風格、**海水礁岩池、改名 Stillwater Reef**、名單是花園鰻＋割草機鳚＋紅雷達＋藍綠光鰓魚（沒有蝦、斧頭魚、絲鰭彩虹魚）、**沒有捕食**、有餵食與敲玻璃、游標引魚。

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

> **大部分已由 Claude 代為處理**：你留在工作目錄的改動（`main.gd` 的拖曳撥水、R 水紋、提示文字，`stream_stage.gd`，`stream_habitat.gd(.uid)`，`test_frontend.gd(.uid)`，`FRONTEND_BACKEND_CONTRACT.md`）已經**原封不動**存成 commit `12ef13d`，當時跑過 `test_frontend` 10/0、`test_presentation` 26/0。之後 Claude 又在上面修了卡頓（§0.5），所以 `stream_stage.gd` 和 `test_frontend.gd` 跟你記得的不一樣，**請先讀現行版本再改**。這一步剩下的只有修正契約文件。

- 先確認現行 `main` 上 `test_frontend` 和 `test_presentation` 都通過。
- 修正 `FRONTEND_BACKEND_CONTRACT.md`：
  - `stream_absence.gd` 改成實際檔名 `scripts/absence.gd`。
  - 引用 `BACKEND_SNAPSHOT_EVENTS.md`。
  - 刪掉捕食演出的描述。
- 分成有意義的 commit 送出。

**驗收**：
- `git status` 裡沒有你的未 commit 檔案。
- `test_frontend` 通過。
- `test_presentation` 通過（它負責證明前端不改動生態）。

### 0.5 先修動作卡頓（最優先，使用者 2026-09-23 回報「動畫卡卡的」）

> **已由 Claude 完成（2026-09-23，commit `9892107`），Codex 跳過這一步，直接做 §1。**
> - 新 helper `scripts/motion_smoother.gd`：保留最近兩份 snapshot 位置，時間軸晚一個 tick，用 snapshot 的 `motion_remainder` 對齊 simulation 時間，線性插值、不外推；首次、重載、離線補算、時間跳超過一個 tick 時直接跳到最新；`relocated_at` 晚於上一份 snapshot 的個體直接跳位。
> - `stream_stage.gd` 改用它（`targets`/`lerp(delta*9)` 已移除）；`main.gd` 只把 `step_clock` 換成「`motion_ticks` 變了才套 snapshot」。
> - `swimmer_rig.gd` 沒改：尾擺用的每幀位移現在本身就平滑（rig `motion` 修前 12.5–31.6、修後 19.7–19.9 px/s，真速 19.7）。
> - 測試：`tests/test_frontend.gd` 新增 30 FPS 真 world+stage 巡游速度測試（固定幀與抖動幀各一）、暫停零位移、helper 單元測試。修前畫面/真實速度比 0.23–3.79，修後 1.00–1.01。
> - 對照片：`artifacts/motion-smoothness/`（見其 README）。
> - 做 §1 的 `relocated_at` 尾流時，沿用 stage 的 `jumps` 判斷即可。

**根因**（Claude 依目前程式邏輯推算，0.5.0 正式包和 Frontend Preview 都有）：
- simulation 的位置每 0.2 秒才更新一次（`advance_live` 以 0.2 秒 motion tick 積分）。
- `main.gd` 用自己的 `step_clock` 每 0.2 秒套一次 snapshot，跟 motion tick 沒有對齊。
- `stream_stage.gd` 的 `animate` 每一幀用 `rig.position.lerp(targets[id], delta*9)` 往目標追。

結果是每 0.2 秒一次「衝一下、慢下來、停住」。以一隻穩定 40 px/s 游動的魚計算，畫面上每一幀的速度在 **9 到 150 px/s 之間擺盪**，約 16 倍；兩個 0.2 秒時鐘漂移時，還會週期性一次跳兩步。這就是卡頓的來源。

**修法**（前端，不改 simulation）：
1. 在 stage 保留最近兩份 snapshot，照 snapshot 的 `elapsed` 做**時間插值**：畫面位置 = 兩份 snapshot 位置的線性插值，時間軸比最新 snapshot 晚一個 tick（0.2 秒）。延遲對觀察型魚缸看不出來，而且轉彎不會過衝。拿掉 `lerp(targets, delta*9)` 這種追目標的寫法。
   - 備選做法是用 `vx/vy` 從最新 snapshot 往前外推，但轉彎時會過衝，不建議。
2. 插值時間用 simulation 時間：每幀依 `advance_live` 實際推進的時間累加。暫停時停住；隱藏／恢復、離線補算、世界重載之後，直接跳到最新位置，不插值。
3. `relocated_at` 落在兩份 snapshot 之間時，這一段直接跳位，不插值、不畫尾流（和 §1 的第 3 點合併處理）。
4. snapshot 套用時機要跟 motion tick 對齊：`main.gd` 的 `step_clock` 改成「`world.state.motion_ticks` 有變化才套用新 snapshot」。這是 `main.gd` 裡唯一允許你改到 `_scene_input` 以外的地方，只改這一段。
5. 朝向（`face_target`）和尾擺強度也改用插值後的速度，不要用追目標時的暴衝速度，否則尾巴會跟著抽動。

**驗收**：
- 在 `test_frontend` 加一個測試：用真的 `StreamWorld` 以 30 FPS 推進 10 秒，記錄一隻正在巡游的魚每一幀的畫面位移。直線巡游段的每幀速度變化，不得超過真實速度的 ±25%（目前會擺盪到約 16 倍）。暫停時位移為 0。
- 再錄一段 1.65 倍的短片，放在 `artifacts/motion-smoothness/`，附修前修後對照給使用者看。
- `test_presentation` 通過，證明 snapshot 仍是只讀。

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

照 handoff §2 的表格做，但只做魚和花園鰻用得到的：出生、自然死亡、移入、幼體漂走（脫殼與抱卵已隨蝦取消）。都要非血腥，都不能改變動物軌跡或生態。
- 暫停時 delta=0，演出要凍結；隱藏時停止更新。

**證據要用真的模擬觸發**：做一個可重現的 scenario 工具（放在 `tools/`，例如 `tools/event_review.gd`）。它用固定種子建立真正的 `StreamWorld`，推進到自然發生出生、死亡、漂走、移入，並在事件發生時截圖。**不要先把角色藏起來、再由 UI 假裝發生了事件**，也不要用 `tools/swimmer_scene.gd` 的固定示範當證據。scenario 的模擬時間要短，能用 `advance_offline` 快轉到事件附近、再用 `advance_live` 看演出就這麼做，避免長時間跑。

**驗收**：
- `artifacts/event-review/` 裡每種事件至少一組截圖（事件前、演出中、完成後），附一份 `README.md` 列出種子、模擬時間、事件 id。
- 補上演出的狀態測試：開始、進行中、完成；暫停時凍結；演出數量有上限，不會一直累積。

### 3. ~~蝦精緻化~~（已取消：使用者 2026-09-23 決定拿掉蝦）

跳過，直接做 §3.5。

### 3.5 花園鰻（使用者 2026-09-23 逐題確認）

新物種：斑點花園鰻（*Heteroconger hassi*）。它是海水魚，使用者明確說**不用管淡水海水**，照加，不要再提這個問題。

**已定的設計**（backend 由 Claude 做，欄位完成後會寫進 `BACKEND_SNAPSHOT_EVENTS.md`，這裡先列出你會拿到的東西）：
- 開局 2 隻，和其他魚一樣會長大、繁殖、老死、餓死；壽命約一年、約三個月成熟。
- 最多 4 隻，多生的幼魚照既有規則漂到下游。
- 族群目標見最上方的最新決定（11–16 隻），硬上限 24 不變。
- 吃水中漂過的小生物。
- 每隻有**固定的沙洞**。沙洞聚在沙地中央一小區，像一小片花園鰻草原。花園鰻不會離開自己的洞游來游去；幼魚出生後會在附近挖新洞。
- 行為由 backend 決定，前端照 snapshot 呈現：
  - 白天：站出沙面，身體對著水流搖擺，吃漂過的小生物。
  - 夜裡：全部縮回沙裡睡覺。
  - 有魚游過太近：縮一下，幾秒後再探出來。
- snapshot 會提供（2026-09-23 已實作，細節見 `BACKEND_SNAPSHOT_EVENTS.md` 的「花園鰻」一節）：
  - `species:"garden_eel"`（`StreamWorld.SPECIES.garden_eel.label` = "Spotted garden eel"）
  - 沙洞座標 `burrow_x/burrow_y`（`burrow_y = floor_y(burrow_x)`，x/y 永遠等於洞口，`vx=vy=0`）
  - 伸出比例 `extend`（0＝完全在沙裡，1＝完全站出；backend 只給 0 或 1，前端自己平滑）
  - `activity`：`Swaying`、`Retracted`、`Sleeping`
  - 移入的個體直接出現在洞口（`arrival` 的 x/y＝洞口）；「從上游游進來」由前端純呈現
  - 性別、年齡照舊

**前端要做**：
1. **素材與 rig**：細長身體、斑點花紋、小頭大眼；身體從沙洞口「長」出來，下半段藏在沙裡。
   - 搖擺是從洞口往上遞增的波動，頭部對著水流微微點頭進食。
   - 伸出與縮回要平滑，由 `extend` 驅動，不能直接跳。
   - 洞口在沙面上有一圈小小的凹陷或沙粒，縮回時看得到洞。
   - 保持 Soft Pixel，比例和其他魚協調。
2. **你的操作觸發縮回（使用者要求）**：在花園鰻附近拖曳撥水或按 R 打出水紋時，附近的花園鰻在**畫面上**縮回洞裡，幾秒後慢慢探出來。
   - 這只是呈現層的反應，**不得寫回 simulation**：不改 `extend`、activity、飢餓、繁殖或任何生態狀態。`test_presentation` 要繼續通過。
   - 畫面上最後的伸出比例，取 snapshot 的 `extend` 和這個觸碰反應兩者中較低的那一個。
3. **事件演出沿用 §2**：出生時幼魚從親代附近的新洞口探出來；死亡時縮回洞裡後淡出，洞口留一小段時間再消失；移入的個體從上游邊緣游進來、鑽進洞。
4. **先給使用者看比較圖，再整合**：
   - 在一般視角與 1.65× 下，各截一組白天搖擺、半伸出、縮回、夜裡睡覺的圖。
   - 一段撥水觸發縮回再探出的短片。
   - 放在 `artifacts/eel-review/`，附素材來源與 prompt。
   - **使用者說好才接進正式版。**

**驗收**：
- 使用者核可比較圖。
- `test_frontend` 補上以下檢查：觸碰會讓附近花園鰻在畫面上縮回、之後恢復；觸碰前後 `export_state()` 位元組不變；夜裡 `Sleeping` 時完全看不到身體、只看到洞口。
- `test_presentation`、`test_swimmers` 都通過。
- backend 欄位還沒到之前，先做素材和比較圖。缺欄位就寫清楚要什麼交給 Claude，不要在前端自己模擬花園鰻的行為。

### 3.6 餵魚、敲玻璃、游標引魚（使用者 2026-09-23 要求，backend 已完成：commit `6c2910d`）

欄位、事件與常數以 `BACKEND_SNAPSHOT_EVENTS.md` 的「餵食、敲玻璃、游標引魚」一節為準。backend 已經在 `main.gd` 做了暫時的接線：F 撒飼料、T 或點水域外的邊框敲玻璃、游標停住引魚。你負責讓它看得見、用起來順手。

1. **飼料**：畫 snapshot 的 `food`，每粒都有 `x/y/settled`。下沉時可以微微飄動，但位置以 snapshot 為準，不要自己模擬下沉。沉到底之後慢慢變暗，消失時間照 backend 的 900 秒。水面撒下時做一個小小的落水效果（事件 `fed`，`live:true`）。
2. **吃飼料**：`activity:"Feeding"` 的魚在接近 `food_id` 那粒時做一個張口咬的動作；花園鰻叼走飼料時，身體往前探一下。
3. **吃飽了**：`feed()` 回 `false` 時，`main.gd` 已經在狀態列顯示 “They’re full for today — natural food keeps them going.”。可以再加一個輕的視覺提示，例如飼料罐搖不出東西，但不要做成懲罰或警告。
4. **撒飼料的操作**：現在只有 F 鍵。請設計一個不用鍵盤的方式，例如畫面上一個小飼料罐按鈕，或在水面上點一下。**不要跟「點動物＝選取」衝突**。改的是 `_scene_input` 和提示文字，呼叫 `world.feed(x)` 就好，不要自己改生態。
5. **敲玻璃**：`world.startle()` 已經會讓魚衝開（`activity:"Startled"`）、花園鰻縮回。你要做的是敲下去的回饋：玻璃上一圈細微的震紋，或畫面輕微一震（要很輕）。
   - 目前「點水域外的邊框」只有在視窗比例不是 16:9、出現黑邊時才點得到。請決定一個一定點得到的方式，例如點水面上方的空白處，或畫一圈可以點的魚缸邊框。
6. **游標引魚**：`activity:"Curious"` 的魚會停在游標旁邊。可以加一個很淡的提示，讓使用者知道牠們在看游標，例如魚頭朝向游標、眼睛反光。不要畫十字準星這類遊戲 UI。
7. 這些效果都不能寫回 simulation，`test_presentation` 要繼續通過。暫停時全部凍結。

**驗收**：
- `test_frontend` 補上以下檢查：飼料照 snapshot 畫出、數量正確；`Feeding`／`Startled`／`Curious` 這三種活動有對應的呈現；不用鍵盤也能撒飼料和敲玻璃。
- 附一段短片給使用者看：撒飼料 → 魚游過去吃 → 吃飽了的提示；敲玻璃；游標引魚。

### 3.7 海水礁岩池（使用者 2026-09-24 決定）

這是目前最大的一塊前端工作。先做素材和比較圖，**停下來給使用者看，使用者說好才整合**（跟蝦、花園鰻同一套流程）。

1. **背景**：把溪流背景（苔木、淡水水草、水面浮萍）重畫成**海底沙地加礁石**，保持同樣的 Soft Pixel 風格、640×360 內部解析度、nearest sampling、固定側視構圖。
   - 中央沙地要留給花園鰻和紅雷達的洞穴區：backend 的洞口在 x≈550–790 一帶，實際座標見 `BURROWS`。
   - 要有割草機鳚可以趴的石頭或礁石表面。
   - 中層要留出開闊水域給藍綠光鰓魚群游。
   - 遠景是藍綠色的海水，光線從水面灑下。**不要出現淡水植物**。
   - backend 資源池只改叫法：`stem` 改成海草、`floating` 改成漂浮藻、「溪流交換」改成海流。前景水草層（`stream_habitat.gd`）的外觀請跟著換成海草或漂浮藻。
2. **三種新魚的素材與 rig**：
   - **割草機鳚**：斑駁的米褐色身體、厚唇，頭上有小觸鬚。趴在底上時用胸鰭撐著，短距離一跳一跳地移動。刮藻時嘴巴貼著表面。
   - **紅雷達**：前段白、後段漸層到橘紅，背鰭第一根棘很長，常常會輕輕抖動。懸停在自己洞口上方，一受驚就瞬間鑽回洞裡。
   - **藍綠光鰓魚**：小型，全身藍綠色、帶一點金屬光澤。成群游，每條要能看出各自的位置和朝向，但整群一起轉向。
   - 比例參考真實體型：花園鰻最長；割草機鳚和紅雷達是小型魚；光鰓魚最小。
3. **事件與互動**沿用 §1、§2、§3.6，對應到新物種：
   - 出生、死亡、移入、漂走的演出。
   - 餵食：每種魚吃飼料的方式不同（鳚在底部啄、紅雷達從洞口衝出來叼、光鰓魚在水中搶食）。
   - 敲玻璃：紅雷達鑽洞、光鰓魚群散開再聚回來。
   - 游標引魚。
   - 具體活動名稱等 backend 完成後，以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。
4. **標題**：app 標題和副標題改成 Stillwater／REEF（backend 會改 `main.gd` 裡的字串，你只要確認畫面上的排版）。

**比較圖**放在 `artifacts/reef-review/`，內容包括：
- 新背景的一般視角與 1.65× 各一張。
- 四種動物各自的特寫。
- 一段光鰓魚群游、紅雷達鑽洞、割草機鳚刮藻的短片。
- 附上素材來源與 prompt。

**驗收**：
- 使用者核可比較圖。
- `test_frontend`、`test_swimmers`、`test_presentation` 都通過。
- 四種動物在正式包的一般視角和 1.65× 下都清楚可辨，身體接觸地面或洞口的地方沒有穿模。

### 3.8 自然游動：用 backend 數值驅動身體與鰭（使用者 2026-09-25 要求「以自然為主」）

> **2026-09-26 使用者澄清方向（最高優先，會影響 §3.8 怎麼做）**：使用者原話：「我要的細節不是要很擬真、很像真的魚，而是動作要自然、要流暢。」
> - **目標是流暢自然的動畫感，不是生物寫實**。不需要照真實解剖去加鰭條、鱗片、肌肉變形，也不要為了「像真魚」而加入抖動、急停或複雜的小動作。
> - **優先做這些**：動作之間要平順銜接，例如游→滑→停→轉身→再游，不要有突然的切換或卡一下；加減速要柔和（ease in／ease out）；轉身要有弧度和延遲，由頭帶動身體、尾巴跟上；身體要有一點延遲的「跟隨感」和輕微的慣性、回彈；待機時也要有很輕的呼吸感，不能完全靜止，也不能抖。
> - **判斷標準**：看起來順、看起來舒服，比數值上「符合真實魚類」更重要。如果 backend 的某個數值直接套上去會顯得生硬（例如 `thrust` 在 0 和 1 之間跳），前端可以自由平滑它、加緩衝。前端呈現不必逐格照抄 backend，只要不寫回 simulation、位置不離開 backend 給的座標太遠。
> - 各物種的特色保留（光鰓魚群游、黃金吊滑行、紫雷達懸停、鳚跳一下），但都要以「流暢」為先。
> - 驗收一樣是給使用者看每種魚的 1.65× 修前修後短片，由使用者判斷順不順。

使用者覺得魚的動作生硬、不自然，確認的問題有三個：游的路線與節奏、轉向、身體與鰭的擺動。前兩項 Claude 已經改完 backend（commit `9956a41`、`2b8147a`、`b66742a`、`84c4bc0`），第三項由你做。

**backend 現在提供的欄位**（細節見 `BACKEND_SNAPSHOT_EVENTS.md`；證據見 `artifacts/natural-motion/trace.json`，由 `tests/natural_motion_trace.gd` 產生）：`heading`（0 到 π 連續，π/2 是正對玻璃）、`pitch`、`speed`、`thrust`（0–1）、`turn`（rad/s）、黃金吊的 `roll`、紫雷達的 `flick`。`direction` 與 `vx/vy` 保持相容。

**你要做的**：
1. **轉身**：左右鏡像用 sign(cos(heading))，身體寬度用 |cos(heading)| 壓縮，正對玻璃時最窄。用 `turn` 做「頭先轉、尾巴延遲跟上」。不要再用左右一下翻面。
2. **身體與鰭由數值驅動，不要播固定循環**：
   - 藍綠光鰓魚：thrust≈1 時胸鰭划水，thrust≈0 時滑行、鰭收起；尾巴擺幅跟著 speed。
   - 黃金吊：thrust 決定平穩划水的幅度；roll 是啃石頭時的側傾；轉大彎時身體有弧度。
   - 紫雷達：懸停時用 pitch 做微小平衡，胸鰭與尾鰭輕輕扇；`flick`=1 時背鰭長棘彈起再收回（由你做彈回的動畫）；thrust=1 是衝回洞，要快而有爆發感。
   - 割草機鳚：停著不動、眼睛會轉；thrust>0 那一 tick 是甩尾，之後滑行落地，胸鰭撐地。
   - 鰭的節拍相位請用 thrust 在前端積分產生。snapshot 每 0.2 秒才一份，backend 無法提供高頻相位。
3. **沒有這些欄位的舊資料**：heading 由 `direction` 推算，其他當 0。
4. **黃金吊剛到岩石點時會先原地轉身才開始 `Grazing`**，請讓這個轉身看起來自然。

**驗收**：
- 先給使用者看，說好才算完成：每種魚一段 1.65× 的**修前修後對照短片**，要看得出「衝一下、滑行」的節奏、彎曲的路線、頭先轉尾巴跟、各物種的特色動作。
- `test_frontend`、`test_reef_animation`、`test_natural_motion`、`test_presentation` 都通過。
- 另外補一個測試：同一段 snapshot 序列下，畫面上的朝向不會一格就翻面。
- 短跑效能自查：跟 §4 一樣，這不是正式驗收。

### 3.9 §3.8 使用者回饋修正（2026-09-26）

> **2026-09-26 使用者看完 §3.8 對照片的回饋（優先修）**：
> 1. **紫雷達「影子還在、直接穿模進沙子」**：Claude 逐格看過，受驚時大約只花 1 格（約 0.13 秒）就消失在平坦的沙面裡，沙上只剩一個小黑點（使用者以為是影子，其實是洞口標記），完全看不出有洞，所以像穿模。要改成：
>    - 沙面上畫出**看得出來的洞口**：一個小黑口，外圍一圈微微隆起的沙緣，醒著、睡著、不在洞裡時都看得到，而且要是洞口的樣子，不能像影子。
>    - 鑽洞要**看得到過程**：約 0.4–0.6 秒，頭先沿著弧線往下，身體依序被洞緣遮住（用遮罩或裁切，不能直接穿過平坦沙面），帶一點點沙粒揚起。從洞裡出來時反過來做。
>    - 「爆發感」要靠開頭加速來表現，不是靠瞬間消失。backend 的 thrust=1 只代表開始衝，前端可以自由拉長整段動畫。
> 2. **黃金吊「被壓扁」**：啃礁石時身體被壓成窄條，看起來像一直停在轉身的一半。原因是 backend 把身體中心放在離接觸點只有 22 px，前端為了讓嘴碰到礁石，就把整條魚往深度方向轉過去壓縮。**Claude 正在改 backend**：身體中心會移到離接觸點約半個身長（依體型縮放），用側面就碰得到。請你**移除啃食時的縮短與壓扁**（`reef_rig.gd` 的 `contact_projection` 那段），改成側面啃食，只保留輕微的 roll 和 pitch 點頭。欄位如果有變，以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。
> 3. 驗收：重新交紫雷達和黃金吊的 1.65× 對照短片（紫雷達要包含受驚鑽洞與出洞），由使用者判斷。

### 4. 效能自查（短跑，不是正式驗收）

正式的 30 分鐘驗收由 Claude 在你交付後跑，只跑一次。你這邊只做短的自查，及早發現明顯超標：
- 用 `-- --qa --duration=120` 跑一次打包版，視窗保持在前景，看 `qa-performance.json` 的 frame 數據，再用 `tools/sample_process.py` 取樣 CPU/RSS。
- 目標：前景平均 CPU <15%（一核心 = 100%）、RSS <350MB、30FPS。
- 若超標，照 handoff §4：先減裝飾效果，不犧牲魚和花園鰻的可讀性，不改 simulation。
- 測試期間不要同時 export、錄影或跑其他模擬。

**驗收**：短跑數字記在交付報告裡，並註明「非正式 30 分鐘驗收」。

### 5. 交付

最後一個 commit 之後，回報以下內容：
- 每一步標「已完成／未完成／需要 backend」。
- 比較圖和事件截圖的位置；使用者核可花園鰻的時間點。
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
- 花園鰻經使用者核可，並已整合。
- 短跑效能沒有明顯超標。
- 前端測試全部通過，`test_presentation` 證明前端沒有改動生態。
