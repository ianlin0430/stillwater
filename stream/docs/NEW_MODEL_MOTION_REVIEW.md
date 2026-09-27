# 2026-09-27 新模型動畫 review（§3.10）

**前端候選已實作、全部指定測試通過，使用者動態核可未完成。** 不把本次交付寫成 §3.10 全部核可。低像素側面 atlas 和 `LOOK` 的 region／身體尺寸沒有改。

## 對照

本機產物在 `artifacts/new-model-motion-review/`。每種魚有 `<species>.mp4`（30fps、1.65×）、`<species>-comparison.png`（六個狀態的修前修後照片）、`<species>-frames.png`（12 格動作逐格圖），上修前／下修後。影片不是 1.65 倍播放速度，是世界像素乘 1.65 的鏡頭。修前使用本次開始時的 rig、shader、portal、events 封存；兩版使用相同輸入。

- 鳚：22 秒。完整跳躍、啃床面、飼料啄食、真實 `StreamEvents` 移入呈現、睡眠與影子。
- 紫雷達：22 秒。懸停／長棘回彈，3s 受驚進洞，5s 出洞，8s 夜間回洞，10s 出洞／10.6s 再受驚，16.5s 探食，18s 幼體到成體。
- chromis：22 秒。群游划水與轉身、7s 休息、11s 散開再聚、好奇／咬食、19s 死亡降速淡出。
- 黃金吊：38 秒。0–26s 直接用 backend 控制場景的繞弧（seed 42，休息 chromis 不側滑）；26s 減速、30s 側面啃食、34s 慢速完整轉身。後三段是受控 pose 重播，不宣稱修好 backend 減速門檻。

重建：先保存修前檔到上述目錄，再跑 `godot --path stream --script res://tools/new_model_motion_review.gd`，用有 Pillow 的 Python 跑 `tools/package_motion_review.py`。影片、圖表和封存檔屬本機 artifacts，不提交影片／原始逐格 JPEG。

## 建議順序與結果

1. **已完成核對**：既有核可 atlas 不變。`atlas-anchors.png` 疊出四種魚胸鰭根、眼、嘴；胸鰭根改為 tang (.66,.61)、firefish (.73,.68)、blenny (.70,.74)、chromis (.67,.60)。舊鰓和眼的 mesh 微變形移除，鰓改為整個色塊輕微明暗呼吸；眼不再被 mesh 拉扯。長棘遮罩改用原始 atlas 座標而非變形後座標。
2. **已實作、待目視核可**：網格 32×24 降為 16×12，身體微變形減少；胸鰭保留連續、獨立時鐘，懸停改成緩慢整体偏移。洞口沙緣與粒子採 3px，影子用像素矩形色塊淡入淡出；4px 飼料改成整塊，水紋改為格點折線。洞口 shader 半徑隨 body_scale 反向補償，幼體洞口保持原世界尺寸。
3. **已接入候選、未核可**：四種魚中間／正面圖，來源與完整 imagegen prompts 見 `assets/reef/PROVENANCE.md`。只顯示一個姿勢，不做兩組眼睛交叉淡入。轉場逐格圖特別保留換姿勢節點，請使用者評估輪廓與眼睛是否一致。
4. **已實作**：sleep_blend、連續 breath_clock、尾擺緩停、影子淡入淡出、黃金吊 contact pitch 緩入緩出、死亡出力／尾擺／胸鰭衰減。紫雷達轉頭延至進洞前 60% 階段；受驚總行程 .68s（可見部分需看逐格）、夜间 .95s；出洞仍 1.3s；懸停漂移淡入淡出。移入依距離調成 2.5–5s，避免 1.6s 橫越半個畫面。
5. **已實作**：鳚落地輕頓、空中加力排下一跳、整格眼睛反光移位、啄食、沿床面移入；黃金吊減速張鰭、跟 roll 同步的點頭及咬；背鰭欠阻尼回彈；紫雷達左右漂與 food_x/food_y 探食；幼體用每秒 .16 倍的速度長大。所有動畫狀態在 delta=0 凍結，隱藏舞台停止更新。
6. **已接 backend**：「大魚繞小魚」只讀 heading/pitch/turn 等原有欄位，沒有讀 around_x/around_y。baccaa8 的胸鰭平滑保留；休息速度驅動改為最大 .22、12px/s 正規化的小幅 spacing 回位划水。測試訊息不再寫 tang side-slip。
7. **已查看**：`light-review.png` 白天、夜間、觀賞燈四魚辨識；夜間較暗，輪廓仍可辨。

## 使用者要判斷

- 出洞被打斷：目前先完成出洞，再鑽回去（影片 10–14s）。是否改成當下掉頭仍未核可。
- 晚上回洞：候選比受驚從容（8–10s），是否採用仍未核可。
- 中間／正面圖及切換、粗像素動作整體是否流暢，仍需使用者看圖決定。

## 驗證

- `test_reef_animation`: 61 checks，0 failures。
- `test_frontend`: 80 checks，0 failures。
- `test_swimmers`: 103 checks，0 failures。
- `test_presentation`: 29 checks，0 failures。
- `test_low_pixel_transitions`: 30 checks，0 failures。相同 transition suite 在封存修前 rig 上有 21 個失敗（26 checks；新成長欄位不存在時不執行其後四個收斂檢查）。紅／綠輸出保存在 artifacts。新增檢查涵蓋 sleep、breath、growth、pause、death、幼體洞口、轉頭速度、長棘回彈、tang pitch、hidden。
- **已通過**：`test_natural_motion` 全預設 seed 集合 46 checks，0 failures。第一次跑曾發現接近岩石 max dv=11.72px/s；Claude 隨後提交 `5e4ae25`，本次重跑 max dv=2.40px/s、110 次接近、0 tick 超標。修前失敗輸出在 `backend-natural-motion.log`，最新通過輸出在 `backend-natural-motion-latest.log`。本次沒有修改該測試或 backend。
- backend 工作目錄原本已有 `stream_world.gd`、`test_natural_motion.gd` 修改；本次沒有編輯或提交它們。

效能數字另見下方短跑結果；不是正式 30 分鐘驗收。

## 120 秒短跑（非正式 30 分鐘驗收）

最新打包版 `Stillwater Reef Frontend QA.app`，啟動參數 `-- --qa --duration=120`，Apple M5。前景／可見 115.026s（扣除啟動暖機），隱藏 0s；3435 frames，mean frame 33.472ms（約 29.88 FPS），p95 33.333ms。`sample_process.py` 平均 CPU 11.54%（一核心=100%）、最高 RSS 248.28 MiB（約 260.34 MB）。低於 CPU 15%／RSS 350MB 門檻；正式存檔 SHA-256 前後一致。完整樣本與 QA JSON 在 artifacts。

短跑量測完成後，Claude 的 backend `5e4ae25` 已落地；指定 backend 測試已重跑並通過，QA app 也已重新打包。上述效能數字屬於量測當時的 frontend 候選，沒有對後續 backend 提交重跑 120 秒。
