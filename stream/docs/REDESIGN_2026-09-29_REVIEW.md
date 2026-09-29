# S4 暫停期間：H1、裝飾、H5 與場景預覽

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
