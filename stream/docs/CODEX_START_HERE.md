# 給 Codex 的指令

> **2026-09-26 最新優先工作：`CODEX_FRONTEND_PLAN.md` §3.8 自然游動。** Claude 已經改好 backend 的移動模型並提供 heading/thrust/turn 等欄位；請用它們驅動身體與鰭，做完每種魚各出一段 1.65× 修前修後短片給使用者看。另外，請用 `-- --qa` 啟動打包版，**不要用正常模式開 app**（上次少打 `--` 分隔，建立了使用者的正式世界）。

> **2026-09-24 git 注意（使用者決定把 repo 公開）**：公開前 Claude 會改寫 git 歷史，把所有 commit 的作者改成 GitHub 匿名信箱，所有 commit 編號都會變。這個 repo 的 git 身分已經改成 `ianlin0430 <261552663+ianlin0430@users.noreply.github.com>`，不要改回來。改寫完成之前，請先把手上 staged 的工作 commit 並 push，然後告訴使用者。改寫之後，**絕對不要 force push，也不要把舊的歷史推回去**；請先 `git fetch`，再把自己的工作 rebase 到新的 `origin/main` 上。

> **2026-09-24 使用者核可（經 Claude 確認）**：`artifacts/reef-review/cast-v2.png` 的五個物種**全部核可**，`reef-background-v1.png`／`background-normal.png` 的海底背景**核可**。**黃金吊**（*Zebrasoma flavescens*）加入名單。最終名單：花園鰻 `garden_eel`、割草機鳚 `lawnmower_blenny`、黃金吊 `yellow_tang`、藍綠光鰓魚 `green_chromis`、紫雷達 `purple_firefish`（*Nemateleotris decora*，取代紅雷達）。Claude 正在把 backend 從紅雷達改成紫雷達並加入黃金吊；完成後欄位以 `BACKEND_SNAPSHOT_EVENTS.md` 為準。你可以開始做正式素材與 rig：比例照真實體型（黃金吊最大的一種魚，光鰓魚最小），做完照 §3.7 再給使用者看動態比較。
> **2026-09-24 最新：改成海水礁岩池，app 改名 Stillwater Reef。** 名單定案：**花園鰻**（保留）、**割草機鳚** *Salarias fasciatus*（在石頭和沙底刮藻）、**紅雷達** *Nemateleotris magnifica*（懸停在自己的沙洞上方，受驚鑽洞）、**藍綠光鰓魚** *Chromis viridis*（中層成群游）。絲鰭彩虹魚也拿掉了（現有素材不再使用）。使用者開一個全新的世界，舊的溪流存檔保留。詳細的新工作見 §3.7；各物種的欄位與活動名稱以 `BACKEND_SNAPSHOT_EVENTS.md` 為準（Claude 正在做 backend）。

> **最新需求（2026-09-23）：「不要蝦子 魚就好」。** 蝦的美術迭代、核可與正式整合均取消。以 [FISH_ONLY_CLAUDE_HANDOFF.md](FISH_ONLY_CLAUDE_HANDOFF.md) 為最新分工；以下蝦相關段落只保留為歷史，不能繼續照做。保留魚類工作與環境互動。

> **2026-09-23 最新：使用者決定整個拿掉紅櫻花蝦。** 所有蝦相關工作都取消（蝦精緻化、抱卵、脫殼空殼、蝦素材）。最新範圍見 `CODEX_FRONTEND_PLAN.md` 最上方。

請讀取 `docs/CODEX_FRONTEND_PLAN.md` 並依序執行前端工作；第 0 步收好 commit 之後，最優先做 0.5（修動作卡頓）。規格以 `docs/CODEX_FRONTEND_HANDOFF.md` 為準，backend 欄位以 `docs/BACKEND_SNAPSHOT_EVENTS.md` 為準，美術沿用 `docs/ART_DIRECTION.md` 的 Soft Pixel 風格。先把目前還沒 commit 的前端收好，只 commit 自己的檔案。花園鰻做完素材和比較圖後要先停下來給使用者看，使用者說好才整合。不要在本機跑長時間模擬。每項結果都要標明已完成、未完成或需要 backend，不要只寫「完成」。
