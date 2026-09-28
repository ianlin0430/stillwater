# 2026-09-28 · 新定案第一步

本次依 `REDESIGN_2026-09-28.md` §3 實作。新魚等待風格核可，未接入正式版。

## 交付與狀態

- **待核可**：`tools/art_candidates/redesign-four-fish-v1.png`，左起 chromis／clownfish／seahorse／royal_gramma。內建 imagegen 產出，來源與完整 prompt 見同目錄 `REDESIGN_FISH.md`。正式 chromis atlas 未更動。
- **已實作、動態待看**：`ReefRig` 只用側面 mesh。signed cosine 決定翻面與寬度；最窄以一個內部繪製像素為下限，避免精確 90° 時出現空白格。尾巴延遲只影響輕微彎曲，不會前後半身反向折疊。俯仰穿過翻面點連續，共用 pivot 對齊像素中心。
- **已實作**：640×360 內部畫面，nearest、整數倍、置中留白；UI 使用視窗原生尺寸。正式縮放是 1×／2×，F11 或 ⛶ 切全螢幕。1.65× 只用於使用者要求的比較工具。浮點 simulation／smoother 不取整，僅繪製對齊。
- **已保留**：沉船背景 v2、較寬且低飽和植物、游標引魚抬頭與 delta 動畫過渡、相關錄製工具／前端測試。沉船仍是獨立預覽，尚待 Claude 場景檔與槽位／碰撞座標。
- **已作廢**：正面／中間轉身 v1/v2 不進 production rig，export 也排除這些 PNG。v2 與凍結的舊 rig/shader 只供 `tools/paper_turn_review.gd` 的修前比較。
- **等待 backend**：tang／firefish／blenny 前端與測試均保留；新魚動畫、正式雙場景／裝飾、老死移動淡出後續再接。FPS 60／30／隱藏政策留給 Claude，本次僅驗證動畫在 60 FPS 的 delta 行為。

## 驗證

前端全綠：`test_frontend` 80、`test_reef_animation` 61、`test_low_pixel_transitions` 40、`test_aquascape` 12、`test_swimmers` 103、`test_paper_turn` 20，共 **316 checks**。

實機視窗 900×620／1200×750／1440×900，分別使用 1×／1×／2×；畫面位置為整數、輸入反算通過，F11 進出全螢幕成功。證據 `artifacts/pixel-display-review/`。整數縮放會在小於下一個倍數的視窗留下較多空白，未用非整數拉伸填滿。

四種目前 backend 魚的 **1.65×、8 秒、60 FPS** 修前／修後同畫面：`artifacts/paper-turn-review/comparison-1.65x.mp4`（左修前、右修後）。逐格檢查 480 格，右側各魚 **0 空白格**；包含精確側緣姿勢。結果見 `visibility-check.json`。三種新魚尚未核可，所以未以新魚替代這四段比較。

全部啟動使用 `-- --qa`；無正式世界讀寫。未修改 `stream_world.gd`、`stream_store.gd`、生態測試或 `.github/`。這是前端功能驗證，非 30 分鐘效能驗收。

## 重建

```sh
godot --path stream --script tools/paper_turn_review.gd -- --qa
python3 stream/tools/verify_paper_turn_frames.py # 需 Pillow、numpy，可用 Codex bundled Python
ffmpeg -y -framerate 60 -i stream/artifacts/paper-turn-review/frames/frame-%04d.png -vf scale=1280:720:flags=neighbor -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart stream/artifacts/paper-turn-review/comparison-1.65x.mp4
godot --path stream --script tools/pixel_display_review.gd -- --qa
godot --headless --path stream --script tests/test_paper_turn.gd -- --qa
```
