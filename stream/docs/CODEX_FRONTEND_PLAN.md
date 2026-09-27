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

### 3.10 新模型（低像素）要做的動畫清單（2026-09-27）

> **2026-09-27 使用者要求**：「我覺得可以像素在低一點」「現在有點太寫實了」。四種魚全部保留、輪廓不變，只把像素變粗、顏色變少。使用者已對風格板說「這版可以」，正式 atlas 也已經 commit（`3416370 Integrate approved lower-pixel reef cast with aligned anchors`，見 `assets/reef/PROVENANCE.md`）。**還沒核可的是動態本身。** 下面列出換成新模型後每一個要做、要重做或要核對的動畫。

**前提**
- 行號一律以 HEAD `baccaa8` 為準（`reef_rig.gd`、`reef_motion.gdshader` 工作目錄沒有未 commit 修改）；同時寫函式名，行號對不上時用函式名找。
- 為什麼要核對：`3416370` 已經重設 `LOOK` 的 region 和 `line`，你的 review 也寫 runtime 看起來可讀。但其他位置（`_ready()` 的 `fin_root` `:95`，shader 的鰓 `:63`、眼 `:65`、嘴 `:67`、下胸鰭收折 `:56`、長棘 `:51`）還是照舊圖比例寫的。**每一項都要在新圖上核對，對不上的再改**。核對方式：把 shader 用的 `atlas_point` 座標（鰭根、鰓、眼、嘴、收折範圍）畫成點疊在新 atlas 的 region 上看。下表標 **〔新圖核對〕** 的都是這一類。
- 動作原則照 §3.8 最上面的使用者方向：**流暢自然，不要寫實**。所有切換都要 ease in／ease out；轉身有弧度，頭先轉、尾巴晚一點跟上；有一點慣性和回彈；待機時有很輕的呼吸；不抖、不急停、不突然換姿勢。backend 的數值可以自由平滑，但**不能寫回 simulation**。
- 檔案範圍照 §1（P:23–25）：可以改 `stream_stage.gd`、`stream_habitat.gd`、`stream_motes.gd`、`swimmer_rig.gd`、`*.gdshader`、`assets/`、前端測試、展示場景與 `tools/` 下的前端工具、`FRONTEND_BACKEND_CONTRACT.md`；這次主要會動 `reef_rig.gd`（繼承 `swimmer_rig.gd`）、`reef_motion.gdshader`、`burrow_portal.gd`、`reef_interactions.gd`、`stream_events.gd`、`stream_stage.gd`、`tests/test_reef_animation.gd`。`main.gd` 只動 `_scene_input` 和提示文字。不要改 `stream_world.gd`、`stream_store.gd`、`absence.gd`、`persist_qa.gd`、生態測試、`.github/`。欄位以 `BACKEND_SNAPSHOT_EVENTS.md` 為準，缺什麼寫給 Claude，不要自己算生態。
- 開 app 只能用 `-- --qa` 或 `-- --persist-qa=<id>`，不要用正常模式（會動到使用者的世界）。

**狀態說明**：已有可沿用＝換圖後照用，只要重看一次；部分＝做了一部分，缺的寫在後面；還沒做＝目前沒有這個動畫；需要 backend＝要 Claude 補欄位。

#### 割草機鳚 `lawnmower_blenny`

| 動畫/狀態 | 觸發 | 要求 | 現況 |
|---|---|---|---|
| 停著 | `Perching`（`speed=0`） | 胸鰭撐地、身體不動，只有很輕的呼吸；貼床面不浮空、不陷沙。 | 已有可沿用；撐地高度用 `LOOK.line`（`animate()` `:224`），`3416370` 已重設 line，〔新圖核對〕。 |
| 原地轉向 | 出發前的 `turn`（最多 7 rad/s，受驚 14） | 跳之前先轉頭，身體跟著變窄再翻過去，尾巴晚一點。 | 已有可沿用（`cos(heading)` 壓寬度）；中間／正面姿勢見「跨物種」1。 |
| 跳（甩尾＋弧線＋落地） | `Hopping`，`thrust>0` 那一 tick；y 永遠貼床面 | 尾巴一甩就起跳，0.65 秒低弧線，落地輕輕一頓；在空中不重來、不中斷。 | 部分：起跳、弧線、空中不中斷已有（`6a61518`）；**落地輕頓還沒做**（`hop_height` 只是 sin² 弧線回到 0，`:218`）；空中收到更強的甩尾會被丟掉，見「修飾」5。 |
| 啃床面 | `Grazing`（6–20 秒） | 落地後才慢慢低頭（約 0.3 rad），嘴貼床面一口一口刮；下半身不能被沙切掉；離開時慢慢抬頭。 | 已有可沿用（`a218687`）；下胸鰭收折遮罩（shader `:56`）和嘴位置〔新圖核對〕。 |
| 睡覺 | `Sleeping`（夜裡） | 貼地不動，呼吸更慢；跟 `Perching` 之間平順切換。 | 已有可沿用；`sleep_amount` 切換見「跨物種」4。 |
| 吃飼料 | `Feeding`（跳到沉底飼料）＋ `ate` | 跳到飼料旁，低頭啄一下，飼料在 `food_x/food_y` 收掉。 | 部分：只有嘴張一下（`consume_food()`）；**低頭啄還沒做**（低頭只在 `Grazing`）。 |
| 受驚 | `Startled`（沿床面 90 px/s，3 秒） | 連續幾個快跳（skitter）竄開，每一跳都完整落地。 | 已有可沿用（靠 `thrust` 起跳）；新模型要重看。 |
| 游標引魚 | 不理會 | 不做反應。 | 不用做。 |
| 眼睛 | 停著時 | 眼睛偶爾慢慢看一眼；不能抖。 | **還沒做**（`eye_scan` 固定 0，`:270`）。這是需求（P:228「眼睛會轉」、B:66「眼睛由前端動」）；上次是 Codex 自己選擇先不做（怕抖，N:12），不是使用者取消。新圖一格很粗，不要用 mesh 位移（shader `:65–66` 會把眼睛那一格拉歪），改成整格換位置。 |
| 接地影子 | `Perching`/`Grazing`/`Sleeping` | 影子配新的像素粗細，出現、消失要淡入淡出。 | 部分：寬度 `extent.x*0.34` 換圖後不變（鳚 `LOOK.width` 仍是 100）。要改的是一下開關（`:287`、`_draw()` `:328`）和固定 alpha 0.18（`:331`），加上像素粗細。 |

#### 紫雷達 `purple_firefish`

| 動畫/狀態 | 觸發 | 要求 | 現況 |
|---|---|---|---|
| 懸停 | `Hovering`＋`extend=1`，高度 `hover_y`，`pitch` ±0.065，`thrust` 0.12–0.2 | 停在洞口上方，胸鰭尾鰭輕輕扇，身體用 `pitch` 微微平衡，上下很輕地浮；可以加一點左右飄。 | 已有可沿用；左右飄還沒做；胸鰭根部〔新圖核對〕；上下浮 ±0.7 px 太小，見「跨物種」3。 |
| 背鰭長棘彈 | `flick=1`（約每 12 秒） | 長棘彈起再慢慢收回，有一點回彈。 | 部分：彈起、收回已有；**回彈沒有**：彈簧 `ray_velocity+=(-36*ray_flick-12*ray_velocity)*delta`（`:194`）是臨界阻尼（ζ=12/(2·6)=1），不會過衝，要回彈就把阻尼調小。峰值只有約 1.6 px（見「跨物種」3）。長棘遮罩（shader `:51`）〔新圖核對〕。 |
| 受驚鑽洞 | `Hiding`＋`extend` 1→0，當 tick `thrust=1` | 開頭加速表現爆發感；頭沿弧線往下，身體依序被洞緣遮住，揚起一點沙；全程約 0.4–0.6 秒。 | 已有（`extension` 以 1/0.55 秒前進，`:208`，`5068bab`）；收鰭（`portal_fold` 乘 `fin` 遮罩，shader `:42,69`，只看 abs(y)/extent.y 比例，不是 atlas 座標）新圖要重看；洞口裁切半徑見「洞口」；轉頭太快見「修飾」1。 |
| 晚上回洞睡 | `Hovering`→`Sleeping`，`extend` 1→0 | 比受驚從容一點（例如沒有開頭爆發、慢一點鑽）。**要不要這樣，由使用者看對照片決定。** | 還沒區分：backend 這時一樣送 `thrust=1`（`stream_world.gd:969`，只要剛才在外面就是 1），前端會演成跟受驚一樣的衝刺。前端可以看 `activity=="Sleeping"` 自己區分，不需要 backend。 |
| 出洞 | `extend` 0→1 | 頭先出來，過了洞緣才慢慢放平，回到懸停。 | 已有可沿用（1.3 秒）；新模型要重看。 |
| 洞裡睡 | `Sleeping`＋`extend=0` | 完全看不到身體，只看得到洞口。 | 已有可沿用。 |
| 洞口 | 一直都在（`burrow_x/burrow_y`） | 小黑口＋一圈隆起沙緣，醒著、睡著、不在都看得到；像素粗細要跟新魚一致。 | 換模型要重做：`burrow_portal.gd` 是 1–2 px 的細節，比新魚細很多。shader 裁切 `abs(local_point.x)<21.`（`:87`）對的是 `BurrowPortal.RADIUS=20`（`burrow_portal.gd:4`），洞口改大小時這個 21 要一起改。 |
| 叼飼料 | `ate`（`x/y` 是洞口，飼料在 `food_x/food_y`，左右 22 px、上方 80 px 內） | 身體往飼料快速一探、咬、回到懸停點；不離開洞口太遠。 | 部分：只有嘴張一下；**往飼料探還沒做**。 |
| 敲玻璃 | `Hiding` 5 秒 | 同受驚鑽洞；5 秒後出洞。 | 已有可沿用。 |
| 游標引魚 | 不理會 | 不做反應。 | 不用做。 |
| 朝向 | `heading` 固定 0 或 π | 不轉身。 | 已有。 |

#### 綠光鰓雀鯛 `green_chromis`

| 動畫/狀態 | 觸發 | 要求 | 現況 |
|---|---|---|---|
| 群游划水 | `Schooling`，`thrust` 在 burst（≈1）和滑行（0）之間交替 | 划水時胸鰭用力划，滑行時鰭慢慢收；尾巴幅度跟 `speed`；看得出「推一下、滑一段」。 | 已有可沿用；胸鰭根部、鰓〔新圖核對〕。 |
| 轉身 | `heading` 連續，最多 4 rad/s（受驚 16）；整群幾乎一起轉 | 每條頭先轉、尾巴跟上；整群一起轉但每條看得出自己的位置。 | 已有可沿用；中間／正面姿勢見「跨物種」1。 |
| 上仰下俯 | `pitch` ±0.7 | 身體跟著路線上下柔和地傾。 | 已有可沿用。 |
| 休息 | `Resting`（夜裡多） | 就地懸停，只有很輕的呼吸和鰭微動；不上下抖。**不再為黃金吊側滑**。 | 部分：`baccaa8` 讓休息時胸鰭改由 vx/vy 驅動（為了側滑），要重看，見「backend 變更」1；進 Resting 尾擺一格歸零，見「跨物種」4。 |
| 搶食 | `Feeding`（追下沉飼料）＋ `ate` | 游過去張口一咬，咬完回隊伍。 | 已有可沿用（`ate` 觸發咬）。 |
| 受驚散開 | `Startled`（3 秒），之後回隊 | 快速散開，開頭加速；之後柔和地聚回來。 | 已有可沿用（靠 `thrust`/`turn`）；新模型要重看。 |
| 看游標 | `Curious`（只有領頭魚，整群跟過來） | 停在游標旁，頭朝游標，鰭微張，眼睛可以有一點反光；不要準星。 | 部分：只有鰭多張一點；頭朝游標只是因為從同一側游過去，前端沒有另外轉頭；眼睛反光還沒做。 |
| 讓黃金吊 | 游動中讓路（`avoid_x/avoid_y`） | 跟一般游動一樣，柔和地往上或往下讓。被夾在水層邊緣或牆邊時不讓，改由黃金吊繞。 | 已有可沿用（backend 路線）。 |

#### 黃金吊 `yellow_tang`

| 動畫/狀態 | 觸發 | 要求 | 現況 |
|---|---|---|---|
| 巡游 | `Cruising`，`thrust` 0.5–0.65，每 1.6 秒一點起伏 | 平穩划水、長滑行，身體有一點跟隨感。 | 已有可沿用；胸鰭根部、鰓〔新圖核對〕。 |
| 大轉彎 | 最多 1.2 rad/s（受驚 4.8），轉身約 2.6 秒 | 大弧度轉身，頭先轉、身體彎、尾巴跟上。 | 已有可沿用（寬度壓縮）；中間／正面姿勢見「跨物種」1。 |
| 繞過不能讓路的 chromis | 2026-09-27 新行為：休息中，或在水層邊緣／牆邊被夾住的 `Schooling` chromis（backend `_stuck`） | 從上方或下方平順繞一個大弧。 | 已有可沿用（`heading`/`pitch`/`turn`）；backend 落地後重看。 |
| 接近岩石、減速 | 2026-09-27 新行為：減速進入啃食 | 滑行減速，胸鰭張開煞車；到點前轉身面對岩石。 | 煞車鰭**還沒做**；轉身已有；進 Grazing 時 pitch 一格跳，見「跨物種」4。 |
| 側面啃岩石 | `Grazing`，`contact_x/contact_y`，`roll` 每 1.6 秒一口 | 側面貼著，嘴剛好碰 `contact`；每一口身體往岩面傾、**點頭**（P:246「保留輕微的 roll 和 pitch 點頭」），咬的節奏跟 `roll` 一致。 | 部分：側面、`roll` 已有；**點頭沒有**：`visual_pitch` 只是固定指向 contact 的角度（`:239`），每一口只有 roll 的傾斜和剪切（shader `:72–73`）；咬是固定循環 `sin(phase*9)`（`:279`），沒跟 `roll` 同步；嘴位置〔新圖核對〕；身體比例偏矮見「修飾」6。 |
| 休息 | `Resting`（多半夜裡） | 慢速懸停，呼吸變慢。 | 已有可沿用。 |
| 吃飼料 | `Feeding`＋`ate` | 游過去，一咬。 | 已有可沿用。 |
| 受驚 | `Startled` 3 秒 | 開頭加速衝開，之後滑行減速。 | 已有可沿用。 |
| 看游標 | `Curious`（每隻自己決定，停得比 chromis 遠一個身長） | 同 chromis。 | 部分：只有鰭多張一點。 |

#### 四種共用：幼體、出生、移入、死亡、漂走（§2）

| 動畫/狀態 | 觸發 | 要求 | 現況 |
|---|---|---|---|
| 幼體 | `age < mature` → 0.5 倍 | 同一套動畫縮小；紫雷達洞口**不要**跟著縮成一半。 | 已有縮放；洞口跟著縮，見「修飾」7。 |
| 長大 | 滿 `mature` 那天 0.5→1.0 | 幾秒內慢慢長大，不要一格跳兩倍。 | **還沒做**（`stream_stage.gd:111` 每份 snapshot 直接設 `rig.scale`）。 |
| 出生 | `birth`＋`live` | 在親代旁 1.5 秒淡入；紫雷達從洞口探出來。 | 已有可沿用。 |
| 移入（游泳魚、紫雷達） | `arrival`＋`live` | 從邊緣淡入游進來；紫雷達游到洞口再進入現在的狀態。 | 已有；紫雷達 1.6 秒從畫面邊緣飛到洞口，速度可能太快，要重看。 |
| 移入（鳚） | `arrival`＋`live`（B:221：x=130 或 1150 的床面上） | 沿床面**一跳一跳**進來（B:66 鳚只會跳），y 每一刻都貼當地床面。 | **還沒做**：`stream_events.gd:55–56` 對所有非洞穴魚都只是 x 平移 130 px，y 固定在 backend 給的那一點；床面會隨 x 起伏，鳚會貼沙平滑滑進來，可能浮空或陷進沙。 |
| 死亡 | `death`（old age / starvation） | 2 秒淡出，游泳的魚慢慢沉，紫雷達縮回洞，鳚留在床面；**出力、尾擺、胸鰭都慢慢降到 0**。 | 部分：淡出、下沉已有。**動作沒停**：`_begin_death`（`stream_stage.gd:196–225`）之後不再呼叫 `apply_actor`，`pose_to` 的 thrust/speed 和 `actor.vx/vy` 停在死前最後一份；effort 一直追舊 thrust（`:179`）、黃金吊 `tail_drive` 用舊 `pose.speed`（`:267`）、chromis 被設成 Resting 後胸鰭改由舊 vx/vy 驅動（`:183–184`），魚在下沉淡出時還在划水擺尾。 |
| 漂走 | `dispersal`＋`live` | 小剪影往下游漂、淡出，約 4 秒。 | 已有可沿用（同一張 atlas，換圖自動跟上）。 |
| 離開 | `departure`（只有 `live:false`） | 不演出。 | 不用做。 |

#### 跨物種

1. **轉身姿勢（側面 ↔ 中間 ↔ 正面）**：現在只有側面圖，轉身時靠 `abs(cos(heading))` 壓窄。使用者核可時的方向是接著補「一致的中間／正面姿勢」再驗轉場（`REEF_LOW_PIXEL_REVIEW.md:7`，`PROVENANCE.md` 也寫這張 atlas 沒有）。要求：四種魚各畫側、中間、正面；眼、嘴、鰭根的位置要對齊後再切換；**不能直接交叉淡入**（會出現兩組眼睛）。鳚、chromis 轉得快，黃金吊轉得慢，最容易看出問題。
2. **像素一致**：新圖一格大約 3–4 世界 px（黃金吊的估算，其他物種請實際量）。現在 32×24 網格的變形是連續的，粗像素會被拉成果凍狀。請決定變形怎麼配粗像素（例如擺幅以整格為單位、或只移動整塊），並在 1.65× 下檢查。洞口、影子、飼料、水紋也要配同樣的粗細。
3. **小幅動作比一格還小**：呼吸 0.10 px（shader `:46`）、鰓 0.28 px（`:64`）、咬 0.85 px（`:68`）、紫雷達懸停上下 ±0.7 px（`_firefish_pose()` `:318`）、背鰭長棘峰值約 1.6 px（3.2×(1/6)×e⁻¹×8，`:115`、`:194–195`、shader `:52`）。在 nearest 取樣下不是看不到，就是變成單格閃動（等於抖）。每一項都要重新定幅度：要嘛至少一整格而且慢慢換，要嘛拿掉。
4. **最容易「跳一下」的切換**（每一個都要看過）：
   - 任何狀態 → `Resting`/`Sleeping`/`Perching`：`sleep_amount` 直接 0/1（`:276`）；呼吸換倍率（`:265`，0.65↔1.1 乘在整個累積相位上）時相位會跳。改成平滑過渡。
   - chromis 進 `Resting`：尾擺一格歸零（`:267` 的 `tail_drive=0.0 if ... activity=="Resting"`，`baccaa8` 新加）。
   - 鳚影子一下出現、消失（`:287`、`:328`）。鳚胸鰭已經由 `pectoral_effort` 平滑（`:187`），不用再改。
   - 黃金吊進出 `Grazing`：`:239` 直接把 `visual_pitch` 設成 `atan2(contact.y,|contact.x|)`，離開時直接回 `pose.pitch`（`:213`）。高度差最多 6 px（B:258），約 0.1 rad 一格跳完。要 ease。
   - 紫雷達 `Hovering` ↔ `Hiding`：見「修飾」1–4。
   - 死亡：見共用表。幼體 → 成魚：見共用表。
5. **日夜光**：舞台用 `CanvasModulate` 統一變暗。顏色變少後，晚上可能糊成一團；請在白天、夜裡、觀賞燈各看一次四種魚是否還分得出來。
6. **飼料與撒飼料**：飼料照 snapshot 畫（4×4 px），落水一圈扁水紋；改成跟新魚一樣的像素粗細。
7. **敲玻璃水紋**：1 px 細圈；同上，配新的粗細，要很輕。
8. **游標引魚**：見 chromis、黃金吊的 `Curious`。
9. **選取框**：用 `LOOK` 的大小，換圖自動跟上；要重看位置。
10. **效能**：照 §4：前景平均 CPU <15%、RSS <350MB、30FPS。新圖不能增加太多網格或 draw call。

#### 這次 backend 變更要配合的（2026-09-27，Claude 進行中）

1. **「大魚繞過小魚」**：休息中的 chromis **不再為黃金吊側滑**；黃金吊改成在「不能讓路的 chromis」（休息中，或在水層邊緣／牆邊被夾住的 `Schooling` chromis，backend `_stuck`）上方或下方繞一個平順的大弧。`CODEX_START_HERE.md` 最上面那條側滑說明（`733d02c`）和 B:77–78 會撤回。
   - rig 要表現：黃金吊用 `heading`/`pitch`/`turn` 優雅地傾身轉彎，身體彎、尾巴晚一點，不能僵硬。
   - 你已經 commit 的 `baccaa8`（Drive resting chromis side-slip with independent pectoral strokes）：**保留**獨立、平滑的 `pectoral_effort`/`pectoral_phase`（`:182–188`、shader `:21,60–61`），它讓所有魚的胸鰭不再一下開關。**要重看**：`:183–184` 休息 chromis 用 vx/vy 驅動胸鰭。backend 改完後休息的 chromis 仍會有「被 spacing 推開後滑回原位」的小移動，vx/vy 不一定是 0；等 backend 落地後再決定這段要不要保留。`test_reef_animation.gd:202–213` 四個檢查的訊息（例如「Resting side-slip does not recruit tail propulsion」）還在講為黃金吊側滑，要改名；`NATURAL_MOTION_FRONTEND_REVIEW.md:90` 的「visible real-world side-slip recording」待辦取消。
2. **黃金吊減速進入啃食**：不再全速到點（目前 backend 的未 commit 修改裡還沒有這部分）。rig 要表現：長滑行＋胸鰭張開煞車，然後轉身、貼岩。
3. 確切的欄位意義等 backend 完成後寫在 `BACKEND_SNAPSHOT_EVENTS.md`，以那裡為準。
4. **需要 backend**：`StreamWorld.BODY`（讓身體不重疊）和 `TANG.clear=[130,92]`（兩隻黃金吊的啃食點間隔，`stream_world.gd:146`，B:244「成魚圖 122×87 加間隔」）都是照舊圖高度寫的。新圖同樣寬度下，高度約 94（黃金吊）、59（紫雷達）、45（鳚）、40（chromis）。**Claude 會直接照已 commit 的 `ReefRig.LOOK` 更新**，你不用另外回報；之後如果再改 `LOOK` 的 region，告訴 Claude 一聲。`test_world` 的 `art_box` 直接讀 `ReefRig.LOOK`。

#### 上次 review 留下的修飾（rig 以 HEAD `baccaa8` 為準）

1. 紫雷達鑽洞一開始約 0.13 秒就轉成頭朝下，看起來太急（`_firefish_pose()` `:301` 的 `bend=smoothstep(0,.4,t)`）。放慢轉頭，讓爆發感來自前進加速。
2. 懸停上下浮動在鑽洞開始、出洞結束時一下加上、一下拿掉（`_firefish_pose()` `:316–318`，只有 `extension>.999` 才加）。改成淡入淡出（幅度也要照「跨物種」3 重定）。
3. 看得到的鑽洞只有約 0.40–0.43 秒，在要求 0.4–0.6 秒的下緣（`animate()` `:208`、`_firefish_pose()` `:305–306`）。建議拉到 0.5 秒左右。
4. 出洞被打斷時，會先把出洞做完（約 0.7 秒，最多 1.3 秒）才再鑽回去（`animate()` `:201–207`，`4c18a44`）。這是取捨，**交給使用者判斷**；對照片要放一段。
5. 鳚在空中收到更強的甩尾會被丟掉（`apply_actor()` `:117`、`:119–120`，`6a61518`）。落地後要接上下一跳，或延長這一跳，不能直接忽略。
6. 黃金吊啃食時身高比例約 0.57，atlas 是 0.717（舊圖；新圖是 0.769），原因還不清楚。可能是低出力時鰭收到 0.82（`:193`、shader `:49`）加上 `roll` 的 `cos` 壓縮（shader `:72`），請先量再改。
7. 幼體的紫雷達洞口跟著縮成一半（`BurrowPortal` 是 rig 的子節點，`_ready()` `:99–102`；rig 縮放在 `stream_stage.gd:111`）。注意 `hover_y`、`half+14` 等偏移（`_firefish_pose()` `:295–306`）和 shader 裁切（`:87`）都在 rig 的縮放座標裡：只把洞口拉出來不縮，裁切半徑要改成 `RADIUS/body_scale` 左右，不然洞口和魚身的裁切會對不上。

#### 要問使用者的（放進對照片）

- 出洞被打斷時，要先出完再鑽，還是立刻回頭（修飾 4）。
- 紫雷達晚上回洞睡，要不要比受驚鑽洞從容。

#### 建議順序

1. 正式 atlas 已經 commit（`3416370`）；`BODY` 和 `TANG.clear` 由 Claude 照 `LOOK` 更新（見「backend 變更」4）。
2. 在新圖上核對所有〔新圖核對〕位置（疊點看），對不上的再改。
3. 決定粗像素的變形方式和小幅動作的幅度（跨物種 2、3），重做洞口（連裁切半徑）、影子、飼料、水紋的像素粗細。
4. 中間／正面轉身姿勢，接著驗轉場。這照 `REEF_LOW_PIXEL_REVIEW.md:7` 的順序（側面素材之後就做）；新姿勢要用第 3 步定下的粗細畫，所以排在第 3 步後面。
5. 修飾 1–7、「跳一下的切換」、死亡時動作停下來。
6. 補還沒做的：鳚落地輕頓、鳚眼睛、鳚沿床面跳著移入、黃金吊點頭和煞車鰭、咬跟 `roll` 同步、背鰭回彈、鳚啄飼料、紫雷達探出叼飼料、紫雷達左右飄、幼體慢慢長大。
7. backend 的 2026-09-27 變更落地後，接上黃金吊繞弧與減速，重看休息 chromis 的胸鰭驅動和 `baccaa8` 的測試名稱。

**驗收**：
- 每種魚一段 1.65× 的**修前修後對照短片**，加一張逐格圖（frame sheet），由使用者判斷順不順。紫雷達要有受驚鑽洞、晚上回洞、出洞、出洞被打斷；黃金吊要有繞過 chromis、減速到岩石、啃食；鳚要有連跳、啃、啄飼料、移入；chromis 要有群游轉身、休息、散開再聚；至少一段死亡。
- `test_reef_animation`、`test_frontend`、`test_swimmers`、`test_presentation` 全部通過；`test_natural_motion` 是 Claude 的測試，不要改，只要求通過（P:206、P:235）。新的切換（修飾 1–7、長大、`sleep_amount`、黃金吊 pitch、死亡停動作、影子淡入淡出）各補一個先失敗後通過的測試。
- 暫停時（delta=0）全部凍結，隱藏時停止更新（P:102、P:169）：長大過渡、影子淡入淡出、眼睛、`sleep_amount` 平滑、死亡降速都要在 delta=0 時停住，並各有測試。
- 沒有改任何 backend 檔案（`stream_world.gd`、`stream_store.gd`、`absence.gd`、`persist_qa.gd`、生態測試、`.github/`）。
- 照 §4 做一次短跑效能自查，標明「非正式 30 分鐘驗收」。
- atlas 已經 commit；**動態本身**要等使用者看完對照片說好，才算這一節完成。

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
