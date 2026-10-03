# S4 暫停期間：H1、裝飾、H5 與場景預覽

> 2026-10-03 更新：下方 v1 裝飾紀錄保留作歷史；目前 review 已改用 v2，統一成沉船花園畫風。S4 在 `s4-cast-swap`，尚未合併 main。測試修正與接手事項見 `CODEX_2026-10-03_HANDOFF.md`。

## 最新交付：統一畫風（等待使用者核可）

- 礁岩 `assets/reef/background-v2.png` 保留構圖，以沉船花園 v2 的藍灰岩塊、飽和珊瑚與簡化沙地重畫；沉船原圖保留。12 款裝飾改為 `*-v2.png`。四種魚保留已核可的造型和配色，放在同一張總覽驗收。
- `artifacts/unified-style-review/overview.png`：兩個場景與實際預設裝飾、12 款裝飾、四種魚。獨立裝飾／魚為 1.65×；場景縮成雙欄。`reef-165.png`、`shipwreck-165.png` 另提供場景的 1.65× 實際裁景。
- 來源與完整 prompts：兩個 `assets/{reef,decor}/UNIFIED_STYLE_PROVENANCE.md`。PNG 原樣保存，UV 裁切與等比尺寸記錄在 catalog。2 世界單位為一個邏輯渲染格；圖中較大的色塊是多格組成，不宣稱每個手繪色塊都相同大小。
- 新版礁岩 JSON 已重對地形橢圓、岩邊退路與槽位；海葵移開洞口避免遮住進出方向。床面仍符合原測試的 legacy 1-unit 約束，並確認落在新版前景沙面。新版裝飾保留枝幹／開口位置，原有 decor 效果座標經 alpha 與疊圖重驗仍有效，因此沒有為換風格修改容量或 schema。
- `test_scene_data.gd` 122 checks、`test_decor_art.gd` 75 checks 全綠。海葵各 3、三款水草各 4 勾點、每個場景 3 rock_spots。已重新執行 `tools/scene_overlay.gd -- --qa --scene=all` 並目視核對兩張疊圖。

## H5 動作預覽（尚未接正式舞台）

`tools/review_fixtures/h5_snapshots.gd` 以 5 Hz snapshot 驅動 smoother 與 `h5_fish_rig.gd`，60 FPS 錄製。只讀 fixture，不引用／修改模擬世界：

- 小丑魚：海葵內輕扭，4–8 秒 Sheltering 沉入觸手，之後返回；用真實前緣遮擋，沒有整隻透明淡出。
- 海馬：先固定尾巴支點搖擺，2–13 秒放開直立漂向下一支葉片，再勾住。lean 繞尾巴支點轉，hitch 欄位消失後平滑放開。漂速最高約 6 世界單位／秒。
- 皇家范魚：洞外小幅徘徊，3–6 與 10–13 秒入洞，再出洞。約 0.8 秒平滑進出，沿洞口裁切；rock fallback 不套洞口遮罩。
- 全部直接左右鏡像。`test_h5_review.gd` 22 checks：入／出、左右洞口、左右尾巴接觸、暫停、唯讀輸入、無壓窄。錄製 trace 的支點座標最大誤差 0（世界單位；這是幾何量測，非逐像素誤差）。
- `artifacts/h5-motion-review/h5-interactions-165.mp4`：16 秒、60 FPS、1.65×。同目錄保留 stills、fixture-trace.json、checks.json。

## 視覺場景資源與切換預覽

`scenes/reef_visual.tscn`、`scenes/shipwreck_visual.tscn` 共用 `ReefSceneView`，從 JSON 載入背景、槽位及預設裝飾，沒有保存或建立 world。`tools/scene_transition_review.gd` 以 0.75 秒淡出至黑，遮住時切場景，再 0.75 秒淡入；同四個魚節點保留。錄製時 assert 切換當格完全遮住且四魚仍在。

`artifacts/scene-transition-review/scene-transition-165.mp4`：10 秒、60 FPS、1.65×，礁岩 → 沉船 → 礁岩。這是視覺資源與轉場驗收；正式 `set_scene()`／重新分配魚位置等待 S11 合併。正式 stage 目前仍直接使用 background-v1，沒有載入新裝飾／H5 rig；待核可再接線。

```sh
godot --headless --path stream --script tests/test_h5_review.gd -- --qa
godot --path stream --script tools/unified_style_review.gd -- --qa
godot --path stream --script tools/h5_motion_review.gd -- --qa
godot --path stream --script tools/scene_transition_review.gd -- --qa
ffmpeg -y -framerate 60 -i stream/artifacts/h5-motion-review/frames/frame-%04d.png -vf scale=1280:720:flags=neighbor -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart stream/artifacts/h5-motion-review/h5-interactions-165.mp4
ffmpeg -y -framerate 60 -i stream/artifacts/scene-transition-review/frames/frame-%04d.png -vf scale=1280:720:flags=neighbor -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart stream/artifacts/scene-transition-review/scene-transition-165.mp4
```

## 1. 座標（H1）

- `2f22408`：依 1280×720 背景核對地形；礁岩保留測試鎖定的床面與 chromis 水層，另外調整其他魚水層、地形橢圓、槽位與退路點。沉船床面改沿前景沙面，拱門用分段障礙保持開口。裝飾落圖後再次修正局部座標。
- 床面是魚活動的沙面深度，不是把整片有透視的沙灘上緣當成一條線；左礁、船殼和拱門另由 terrain_obstacles 表示。
- `tests/test_scene_data.gd` 原檔 **122 checks 全綠**。海葵每款容量 3；必備植物每款 4 勾點；每場景 3 rock_spots，沒有減少容量。
- `artifacts/scene-overlay/reef.png`、`shipwreck.png` 為最後資料疊圖；`scene-overlay-before/` 為原始佔位資料對照。
- 一個邏輯渲染格＝2 世界單位（1× 鏡頭）；魚尺寸仍見 `assets/reef/PROVENANCE.md`。槽位錨點落在 2 單位格線，素材效果點以實際枝幹／開口為準。

## 2. 裝飾素材

12 款 `assets/decor/*-v1.png`，由內建 imagegen 各自生成、原樣保存；生成 prompt 與來源在 `assets/decor/PROVENANCE.md`。`catalog.json` 只記錄透明裁切區與等比例世界尺寸，沒有改動來源像素。款式 ID 跟 `data/decor.json` 一致：

- 海葵：anemone_green、anemone_pink（兩場景各可選兩款）。
- 可勾植物：seagrass_tall、gorgonian、kelp_short（礁岩前兩款；沉船 kelp_short／seagrass_tall）。
- 躲藏：cave_rock、shell、wreck_bow、table_coral。
- 障礙：brain_coral、rounded_rock、branch_coral。

`ReefDecorView` 用同一份網格做後層／前緣遮擋。植物的四個勾點不隨 shader 擺動，只有葉尖輕搖；魚的尾巴不會被葉尖搖擺拉離支點。所有圖都 nearest、無 mipmaps，沿用魚圖的 alpha cutoff 去除生成來源邊缘的半透明暈光。

`tests/test_decor_art.gd` **75 checks**：款式完整、真透明、裁切有效、勾點在可見圖上、前後層與暫停。`tools/decor_art_review.gd` 產出 `artifacts/decor-review/styles-{1,2}.png` 和 `anchors-{1,2}.png`，均為 1.65×。

## 執行

所有引擎命令最後都有 `-- --qa`。不建立正式世界，不寫使用者存檔。

```sh
godot --headless --path stream --script tests/test_scene_data.gd -- --qa
godot --headless --path stream --script tests/test_decor_art.gd -- --qa
godot --headless --path stream --script tools/scene_overlay.gd -- --qa --scene=all
godot --path stream --script tools/decor_art_review.gd -- --qa
```
