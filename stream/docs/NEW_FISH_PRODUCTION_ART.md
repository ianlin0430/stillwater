# 核可新魚：正式側面素材 · 2026-09-28

依 `CODEX_START_HERE.md` 最上方兩條：風格已核可，直接左右鏡像；正式新魚接入等待 Claude S4。

## 已完成

- `assets/reef/fish-atlas-redesign-v1.png`：2149×732 RGBA，透明背景、無標籤。內建 imagegen 以核可板做背景移除，原樣複製保存，未做 Python 圖像編輯。來源 `exec-9445973d-5955-4bfe-ad0e-c1d915a86130.png`。
- 三個可直接引用的 `AtlasTexture`：`clownfish-side-v1.tres`、`seahorse-side-v1.tres`、`royal_gramma-side-v1.tres`。透明裁切留 4 source px 安全邊；Godot lossless、無 mipmaps、nearest，與舊 chromis 相同 alpha cutoff（.86–.97）。
- `scripts/reef_fish_art.gd` 集中 region、尺寸、身體 pivot、嘴、眼、鰭與尾鉤錨點。chromis 仍引用原 atlas 與原 region，沒有被新生成版本替換。
- `scripts/reef_new_cast_rig.gd` 是待接的繪製 rig，只由獨立 review 工具建立。沿用已測過的直接鏡像與遲滯／冷卻，保留游動時鐘。海馬有直立背鰭與尾鉤搖擺的基礎繪製支援；`clasp_target` 僅是 presentation 預覽控制，**不是 backend 契約欄位**。

| 新魚 | Source region x,y,w,h | 基準寬度（world px） | Body pivot（region 比例） | Mouth（region 比例） |
|---|---|---:|---|---|
| clownfish | 650,198,476,303 | 69.0 | .5,.49 | .986,.49 |
| seahorse | 1234,134,253,420 | 36.7 | .5,.56 | .972,.31 |
| royal_gramma | 1620,235,465,249 | 67.4 | .5,.47 | .985,.47 |

海馬尾鉤錨點為 region 的 `.37,.91`，直立高度約 61 world px。其餘錨點以程式 catalog 為準。鏡像只改相對 pivot 的 x 符號，不壓縮身體或切姿勢圖。

## 驗證

- `artifacts/new-cast-art-review/production-cast.png`：實際引擎 1.65× 深／淺底與正／反向圖。`anchors.png`：青色 body pivot、橘色嘴、綠色尾鉤。
- `artifacts/new-cast-turn-review/`：新四魚各自 8 秒／60 FPS／1.65× 的短片，以及 `all-fish-60fps.mp4`。左側刻意轉向，右側 heading 抖動測試。`flips.json` 記錄每次翻面；`visibility-check.json` 驗證沒有空白或壓窄格。
- 前端 **378 checks** 全綠：原 341 checks + `test_new_fish_art` 37 checks。包含透明背景、可見錨點、region／resource 一致、chromis 原圖保留、鏡像後嘴錨點、位置不跳、海馬 clasp easing／pause，以及 S4 前沒有加入正式 cast。
- 沒有修改 `stream_world.gd`、`stream_store.gd` 或生態測試。所有引擎啟動均用 `-- --qa`，review 不建立世界或存檔。

## 尚未完成／需要 backend

正式 `StreamStage` 仍保留 tang／firefish／blenny，直到 S4 提供新魚種契約。完整小丑魚回海葵、海馬勾住／放開水草、皇家范魚洞口進出、裝飾款式與槽位介面尚未完成；這批素材與基礎 rig 不能當作那些互動已整合的證據。

接 S4 前需要對齊：魚的 x/y 語意、海葵／洞口／可勾點座標與 id、藏入／露出進度、海馬的勾住與漂移狀態、晚年離場狀態，以及共享場景檔的格式。前端不自行定義 backend 欄位。

## 重建

```sh
godot --path stream --script tools/new_cast_art_review.gd -- --qa
godot --path stream --script tools/new_cast_turn_review.gd -- --qa
python3 stream/tools/verify_mirror_turn_frames.py --new-cast # Pillow、numpy；可用 bundled Python
godot --headless --path stream --script tests/test_new_fish_art.gd -- --qa
```

## 完整生成 prompt（內建 imagegen）

> Use case: background-extraction. Edit target: the attached APPROVED four-fish pixel style board. Create its production transparent side-view sprite atlas. Change ONLY these things: remove ALL dark teal background to genuine alpha=0 and remove ALL text labels. Preserve all FOUR approved fish EXACTLY: same canvas 2149x732, same positions and sizes, right-facing side view, same silhouettes, palette, tiny square eyes, chunky square pixel grid, fin shapes and body patterns. Left to right green chromis mint/cyan, orange-and-cream three-band clownfish, upright golden ochre seahorse with curled tail, royal gramma PURPLE FRONT/head and YELLOW REAR/tail. Preserve the original fish designs without adding/removing scales or details; do not smooth pixel edges, change anatomy, add fin rays or change the number of colors. Full fins and tail curls must remain intact. Everything between/around fish and formerly occupied by text must be fully transparent. No teal matte, no outlines added, no glow or shadows, no labels, no checkerboard baked into pixels. Transparent isolated clean production sprites, not a new style exploration.
