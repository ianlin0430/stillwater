# 給 Codex 的指令

> **2026-09-24 最新：改成海水礁岩池，app 改名 Stillwater Reef。** 名單定案：**花園鰻**（保留）、**割草機鳚** *Salarias fasciatus*（在石頭和沙底刮藻）、**紅雷達** *Nemateleotris magnifica*（懸停在自己的沙洞上方，受驚鑽洞）、**藍綠光鰓魚** *Chromis viridis*（中層成群游）。絲鰭彩虹魚也拿掉了（現有素材不再使用）。使用者開一個全新的世界，舊的溪流存檔保留。詳細的新工作見 §3.7；各物種的欄位與活動名稱以 `BACKEND_SNAPSHOT_EVENTS.md` 為準（Claude 正在做 backend）。

> **最新需求（2026-09-23）：「不要蝦子 魚就好」。** 蝦的美術迭代、核可與正式整合均取消。以 [FISH_ONLY_CLAUDE_HANDOFF.md](FISH_ONLY_CLAUDE_HANDOFF.md) 為最新分工；以下蝦相關段落只保留為歷史，不能繼續照做。保留魚類工作與環境互動。

> **2026-09-23 最新：使用者決定整個拿掉紅櫻花蝦。** 所有蝦相關工作都取消（蝦精緻化、抱卵、脫殼空殼、蝦素材）。最新範圍見 `CODEX_FRONTEND_PLAN.md` 最上方。

請讀取 `docs/CODEX_FRONTEND_PLAN.md` 並依序執行前端工作；第 0 步收好 commit 之後，最優先做 0.5（修動作卡頓）。規格以 `docs/CODEX_FRONTEND_HANDOFF.md` 為準，backend 欄位以 `docs/BACKEND_SNAPSHOT_EVENTS.md` 為準，美術沿用 `docs/ART_DIRECTION.md` 的 Soft Pixel 風格。先把目前還沒 commit 的前端收好，只 commit 自己的檔案。花園鰻做完素材和比較圖後要先停下來給使用者看，使用者說好才整合。不要在本機跑長時間模擬。每項結果都要標明已完成、未完成或需要 backend，不要只寫「完成」。
