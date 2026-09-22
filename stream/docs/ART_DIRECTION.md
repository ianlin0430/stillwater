# Stillwater 美術交付 — 0.5.0

2026-09-23。沿用使用者選的 **C / Soft Pixel**：柔和色塊、清楚輪廓、低解析度角色可讀性。固定側視，不改成寫實、不恢復螯蝦。

## 正式資產與構圖

- 背景 `assets/pixel/stream-fish-shrimp.png`：新魚蝦版本。左苔木、右矮苔石、中央安靜水域、底部連續覓食路線。移除原本兩個對稱大洞穴。舊 `stream.png` 僅保留作歷史參考。
- `fish-atlas.png` / `shrimp-atlas.png` 保留既有角色設計及atlas座標，避免重新生成破壞rig。絲鰭魚修長、雌雄鰭差異；斧頭魚深腹與斑紋；紅蝦分節腹部、尾扇、步足、觸鬚。
- 640×360內部畫面、nearest sampling。原始背景大圖由runtime縮放，不使用模糊濾鏡掩飾像素。
- 色調：遠景低對比青綠、苔蘚偏黃綠、沙地暖米色、角色銀金/紅色。游動區不加大量裝飾，以角色為主。

## 動作與環境細節

`swimmer_rig.gd`、`fish_motion.gdshader`：頭先轉、尾部延遲，新增淺弧線保留轉身體積；進食時小幅口部形變。公絲鰭魚在縮小後容易斷成點狀的atlas黑鰭絲，由連接同一脊線變形的細線呈現。母魚不增加公魚長鰭。

蝦維持既有著地步足、覓食前足/口器、觸鬚、連接腹節與單次逃逸尾彈。沒有增加無意義的idle抖動。轉向中仍存在短暫正面窄姿態，是目前2D風格化轉向的限制。

`stream_water.gdshader`：僅岸邊水草區極輕的橫向擺動，沙地與腳底接觸平面固定；水面反光很弱。採階梯像素位移而非整張畫面波浪扭曲。

`stream_motes.gd`：14個低透明度懸浮小點，10Hz重畫，隨固定公式慢慢漂移。不使用simulation RNG，也不建立大量粒子物件。

環境clock由stage的delta推進；暫停傳入0，隱藏時stage不更新、renderer停止。CanvasModulate仍統一管理日夜/觀賞燈。裝飾不代表可食微生物，不能接入資源扣款。

## 生物參考與限制

絲鰭魚形態基準（細長身體、雄魚延長鰭條）參照 [Museums Victoria / Fishes of Australia](https://fishesofaustralia.net.au/home/species/3639)。斧頭魚物種參考 [FishBase](https://www.fishbase.se/summary/10736)。紅櫻花蝦物種資料來源 [USGS](https://nas.er.usgs.gov/Queries/FactSheet.aspx?SpeciesID=2257) 此次全文存取回403，不能宣稱做完新的全面解剖校驗。這是物種可辨識的風格化圖像，不是科學插圖。

植物仍是背景構圖，不隨資源池數量生長；不要對使用者宣稱已呈現動態植物生物量。新背景沒有螯蝦洞；若simulation仍把脫殼的蝦送到舊shelter座標，非美術端應確認座標對應苔木/苔石的保護位置，不能為了沿用舊座標把洞穴加回來。

## 美術驗收與後續分工

正式包需看正常視角、1.65×、觀賞燈與自然光，檢查角色和沙地接觸、身體/鰭連接、環境微動不搶主角。診斷 `scenes/swimmer_study.tscn` 使用正式rig但固定腳本，不是自主生態影片。

新增shader/線條後要重測正式包；舊0.4.0的30分鐘安靜運作結果不能替代0.5.0。實际捕食/躲藏是否發生、事件是否同步，是Claude的simulation/介接工作；若需要新的演出，交回明確事件契約與美術需求。

完整非美術接手清單：`NON_ART_CLAUDE_PLAN.md`。本次背景生成來源與prompt：`art-050-provenance.md`。
