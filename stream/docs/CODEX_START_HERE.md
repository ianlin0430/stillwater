# 給 Codex 的指令

> **2026-09-28 換陣容前置（計畫 H3，請先做）**：Claude 接下來做 S4，backend 會改成送 `green_chromis`、`clownfish`、`seahorse`、`royal_gramma`，不再送 tang／firefish／blenny。請先讓舞台接上你的 `reef_new_cast_rig.gd`：
> 1. `stream_stage.gd` 遇到這三種新魚時用新 rig 畫；遇到不認得的物種不崩潰（跳過或佔位）。`SPECIES` 相關的 key（`main.gd:392`、`stream_stage.gd:86,:213`）要能接受新魚。
> 2. `floor_y` 會從 static 改成跟場景有關（`ReefScene.open(id).floor_y(x)`）；`main.gd:295`、`stream_events.gd:61` 請改成向世界或場景取。
> 3. 請把三種新魚的身體寬高（世界單位，給 backend `BODY`）和「1 個粗像素＝幾個世界單位」寫在 `assets/reef/PROVENANCE.md` 或回覆給 Claude。
> 4. 前端測試要能同時處理新舊魚種，直到 S4 落地；S4 落地後再移除 tang／firefish／blenny 的前端與測試，並更新 `.github/workflows/ecology-batch.yml` core job 的前端測試清單（這一行你可以改）。
> 驗收：前端測試全綠；用 `-- --qa` 錄一段四種新魚在舞台上游的短片給使用者。

> **2026-09-28 場景檔已落地（計畫 H1，請你對座標）**：Claude 在 `edc79de` 加了 `data/scenes/reef.json`、`data/scenes/shipwreck.json`、`data/decor.json` 和載入器 `scripts/reef_scene.gd`（`ReefScene.open(id)`）。座標是世界座標 1280×720，**目前全是從背景粗估的佔位值**。請照你的正式背景與裝飾圖改 JSON 裡的座標：床面 `bed`、各魚水層 `bands`、地形障礙 `terrain_obstacles`、槽位 `slots` 錨點、每款裝飾的障礙／海葵／勾點／躲藏點（相對錨點）。改完跑 `tests/test_scene_data.gd`（122 checks）必須全綠，並用 `tools/scene_overlay.gd -- --scene=all` 產生疊圖（紅＝床面、灰／橘＝障礙、洋紅＝海葵、綠＝勾點、黃＝洞口）自己核對。也請告訴 Claude：新圖 1 個粗像素＝幾個世界單位，以及三種新魚的身體寬高（backend 的 `BODY`）。格式細節見 `docs/plans/2026-09-28-redesign-backend.md` §2。只改 JSON 與座標，不要改 `reef_scene.gd` 與測試；結構不夠用就寫給 Claude。

> **2026-09-28 使用者核可新魚風格板**：`tools/art_candidates/redesign-four-fish-v1.png`（chromis／clownfish／seahorse／royal_gramma）使用者說「新魚風格可以」。請照這張做正式側面素材（透明背景、對齊錨點，跟目前 chromis atlas 同規格），接著照 `REDESIGN_2026-09-28.md` §3 做新魚動畫、裝飾美術與介面。新魚正式接進遊戲要等 Claude 的 backend 換成新魚種（計畫 S4）；在那之前可以先用獨立的 review 工具錄對照片。轉身照上一條：直接左右鏡像。

> **2026-09-28 下午 使用者再改轉身（最優先，取代「紙片式轉身」）**：使用者原話「我覺得轉身不用動畫，就是直接左邊換右邊就好」。
> - 轉身**沒有任何過渡動畫**：不壓扁、不翻面過程，魚在某一幀直接鏡像（朝左 ↔ 朝右）。
> - 判斷朝向要有**遲滯**：backend 的 `heading` 是慢慢轉的，`cos(heading)` 在 0 附近可能來回，前端要確定轉過去了才翻（例如越過一個小門檻），而且翻完短時間內不再翻回，避免左右閃爍。
> - 身體其他動作（游動、鰭、呼吸）照舊，翻面那一幀位置不跳。拿掉紙片轉身的壓窄邏輯與相關測試，改成測「只在確定轉向時翻一次、不會閃」。
> - 驗收：四種魚各一段轉身短片（60 FPS），由使用者判斷。

> **2026-09-28 重新定案（最優先，取代下面所有和魚種、場景、互動有關的舊指令）：請先讀 `docs/REDESIGN_2026-09-28.md`。** 使用者參考 Zen Aquarium 重新整理需求：魚種改成 `green_chromis`、`clownfish`、`seahorse`、`royal_gramma`（tang／firefish／blenny 拿掉），礁岩＋沉船花園兩個場景，固定槽位的裝飾會影響魚，不要聲音，紙片式轉身，前景 60 FPS。你的工作在該文件 §3「Codex」，第一步是三種新魚的低像素風格板給使用者核可。§3.10 裡針對舊魚種的項目不用再做。

> **2026-09-28 使用者決定(最優先,取代 §3.10 跨物種第 1 項「中間/正面轉身姿勢」)**:使用者原話「現在轉身的時候好突兀,還不如用一片轉身就好,不要有正面的動畫」。
> - 轉身**只用側面那一張圖**:像一張紙片翻面,寬度照 `abs(cos(heading))` 平順壓窄,到中間翻成另一面再展開;頭先轉、尾巴晚一點跟上的感覺可以保留。
> - **拿掉中間／正面姿勢**(`TURN_ATLAS`、`fish-turns-low-pixel-v*.png` 的使用),不要切換到正面圖,也不要交叉淡入。素材檔可以留著不用。
> - 翻面那一瞬間(寬度最窄時)不能閃、不能跳一格;轉身全程要順。相關測試改成驗證「只用側面圖、寬度連續」。
> - 驗收:四種魚各一段 1.65× 轉身對照片(修前正面版 / 修後紙片版),由使用者判斷。

> **2026-09-27 最新（最優先）：新模型的動畫清單在 `CODEX_FRONTEND_PLAN.md` §3.10。** 使用者已核可低像素 atlas（`3416370`），還沒核可的是動態。§3.10 列出每種魚每個狀態要做、要重做、要核對的動畫、上次 review 留下的修飾、建議順序和驗收。**注意：使用者看過對照片後改了決定，休息中的 chromis 不再為黃金吊側滑，改成「大魚繞小魚」（黃金吊繞弧）。** 下面那條側滑說明已作廢；你的 `baccaa8` 請照 §3.10「backend 變更」1 處理（平滑胸鰭保留，休息用 vx/vy 驅動那段等 backend 落地再看）。

> **2026-09-27 backend 已落地（`13d100f`，review 修正 `a096307`；取代原本的側滑說明）：大魚繞小魚**。`Resting` 的 chromis 不再為黃金吊側滑或上下讓，原地懸停（只剩被 spacing 推開後的小幅水平移動，`vx` 不再因黃金吊和 `direction` 反向）。黃金吊遇到不能讓路的 chromis（休息中，或被夾在水層邊緣／牆邊）時，提前從上方或下方繞一個平順的大弧再回原航線（整群走同一側；在牠正上下方時沿邊繞開）；休息的黃金吊壓在休息 chromis 上會自己慢慢游開。前端全部用現有的 `heading`/`pitch`/`turn`/`vx`/`vy`；新增的 `around_x`/`around_y` 是 backend 內部欄位，前端不用讀。細節見 `BACKEND_SNAPSHOT_EVENTS.md`「大魚繞小魚」。

> **2026-09-26 使用者看完 §3.8 對照片的回饋（優先修）**：
> 1. **紫雷達「影子還在、直接穿模進沙子」**：Claude 逐格看過，受驚時大約只花 1 格（約 0.13 秒）就消失在平坦的沙面裡，沙上只剩一個小黑點（使用者以為是影子，其實是洞口標記），完全看不出有洞，所以像穿模。要改成：
>    - 沙面上畫出**看得出來的洞口**：一個小黑口，外圍一圈微微隆起的沙緣，醒著、睡著、不在洞裡時都看得到，而且要是洞口的樣子，不能像影子。
>    - 鑽洞要**看得到過程**：約 0.4–0.6 秒，頭先沿著弧線往下，身體依序被洞緣遮住（用遮罩或裁切，不能直接穿過平坦沙面），帶一點點沙粒揚起。從洞裡出來時反過來做。
>    - 「爆發感」要靠開頭加速來表現，不是靠瞬間消失。backend 的 thrust=1 只代表開始衝，前端可以自由拉長整段動畫。
> 2. **黃金吊「被壓扁」**：啃礁石時身體被壓成窄條，看起來像一直停在轉身的一半。原因是 backend 把身體中心放在離接觸點只有 22 px，前端為了讓嘴碰到礁石，就把整條魚往深度方向轉過去壓縮。**Claude 正在改 backend**：身體中心會移到離接觸點約半個身長（依體型縮放），用側面就碰得到。請你**移除啃食時的縮短與壓扁**（`reef_rig.gd` 的 `contact_projection` 那段），改成側面啃食，只保留輕微的 roll 和 pitch 點頭。欄位如果有變，以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。
> 3. 驗收：重新交紫雷達和黃金吊的 1.65× 對照短片（紫雷達要包含受驚鑽洞與出洞），由使用者判斷。

> **2026-09-26 使用者澄清方向（最高優先，會影響 §3.8 怎麼做）**：使用者原話：「我要的細節不是要很擬真、很像真的魚，而是動作要自然、要流暢。」
> - **目標是流暢自然的動畫感，不是生物寫實**。不需要照真實解剖去加鰭條、鱗片、肌肉變形，也不要為了「像真魚」而加入抖動、急停或複雜的小動作。
> - **優先做這些**：動作之間要平順銜接，例如游→滑→停→轉身→再游，不要有突然的切換或卡一下；加減速要柔和（ease in／ease out）；轉身要有弧度和延遲，由頭帶動身體、尾巴跟上；身體要有一點延遲的「跟隨感」和輕微的慣性、回彈；待機時也要有很輕的呼吸感，不能完全靜止，也不能抖。
> - **判斷標準**：看起來順、看起來舒服，比數值上「符合真實魚類」更重要。如果 backend 的某個數值直接套上去會顯得生硬（例如 `thrust` 在 0 和 1 之間跳），前端可以自由平滑它、加緩衝。前端呈現不必逐格照抄 backend，只要不寫回 simulation、位置不離開 backend 給的座標太遠。
> - 各物種的特色保留（光鰓魚群游、黃金吊滑行、紫雷達懸停、鳚跳一下），但都要以「流暢」為先。
> - 驗收一樣是給使用者看每種魚的 1.65× 修前修後短片，由使用者判斷順不順。

> **2026-09-26 最新優先工作：`CODEX_FRONTEND_PLAN.md` §3.8 自然游動。** Claude 已經改好 backend 的移動模型並提供 heading/thrust/turn 等欄位；請用它們驅動身體與鰭，做完每種魚各出一段 1.65× 修前修後短片給使用者看。另外，請用 `-- --qa` 啟動打包版，**不要用正常模式開 app**（上次少打 `--` 分隔，建立了使用者的正式世界）。

> **2026-09-24 git 注意（使用者決定把 repo 公開）**：公開前 Claude 會改寫 git 歷史，把所有 commit 的作者改成 GitHub 匿名信箱，所有 commit 編號都會變。這個 repo 的 git 身分已經改成 `ianlin0430 <261552663+ianlin0430@users.noreply.github.com>`，不要改回來。改寫完成之前，請先把手上 staged 的工作 commit 並 push，然後告訴使用者。改寫之後，**絕對不要 force push，也不要把舊的歷史推回去**；請先 `git fetch`，再把自己的工作 rebase 到新的 `origin/main` 上。

> **2026-09-24 使用者核可（經 Claude 確認）**：`artifacts/reef-review/cast-v2.png` 的五個物種**全部核可**，`reef-background-v1.png`／`background-normal.png` 的海底背景**核可**。**黃金吊**（*Zebrasoma flavescens*）加入名單。最終名單：花園鰻 `garden_eel`、割草機鳚 `lawnmower_blenny`、黃金吊 `yellow_tang`、藍綠光鰓魚 `green_chromis`、紫雷達 `purple_firefish`（*Nemateleotris decora*，取代紅雷達）。Claude 正在把 backend 從紅雷達改成紫雷達並加入黃金吊；完成後欄位以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。你可以開始做正式素材與 rig：比例照真實體型（黃金吊最大的一種魚，光鰓魚最小），做完照 §3.7 再給使用者看動態比較。
> **2026-09-24 最新：改成海水礁岩池，app 改名 Stillwater Reef。** 名單定案：**花園鰻**（保留）、**割草機鳚** *Salarias fasciatus*（在石頭和沙底刮藻）、**紅雷達** *Nemateleotris magnifica*（懸停在自己的沙洞上方，受驚鑽洞）、**藍綠光鰓魚** *Chromis viridis*（中層成群游）。絲鰭彩虹魚也拿掉了（現有素材不再使用）。使用者開一個全新的世界，舊的溪流存檔保留。詳細的新工作見 §3.7；各物種的欄位與活動名稱以 `BACKEND_SNAPSHOT_EVENTS.md` 為準（Claude 正在做 backend）。

> **最新需求（2026-09-23）：「不要蝦子 魚就好」。** 蝦的美術迭代、核可與正式整合均取消。以 [FISH_ONLY_CLAUDE_HANDOFF.md](FISH_ONLY_CLAUDE_HANDOFF.md) 為最新分工；以下蝦相關段落只保留為歷史，不能繼續照做。保留魚類工作與環境互動。

> **2026-09-23 最新：使用者決定整個拿掉紅櫻花蝦。** 所有蝦相關工作都取消（蝦精緻化、抱卵、脫殼空殼、蝦素材）。最新範圍見 `CODEX_FRONTEND_PLAN.md` 最上方。

請讀取 `docs/CODEX_FRONTEND_PLAN.md` 並依序執行前端工作；第 0 步收好 commit 之後，最優先做 0.5（修動作卡頓）。規格以 `docs/CODEX_FRONTEND_HANDOFF.md` 為準，backend 欄位以 `docs/BACKEND_SNAPSHOT_EVENTS.md` 為準，美術沿用 `docs/ART_DIRECTION.md` 的 Soft Pixel 風格。先把目前還沒 commit 的前端收好，只 commit 自己的檔案。花園鰻做完素材和比較圖後要先停下來給使用者看，使用者說好才整合。不要在本機跑長時間模擬。每項結果都要標明已完成、未完成或需要 backend，不要只寫「完成」。
