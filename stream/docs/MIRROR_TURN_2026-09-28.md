# 2026-09-28 下午：直接左右鏡像

依 `CODEX_START_HERE.md` 最上方下午指令，取代紙片式轉身。

## 已實作

- 側面圖的朝向永遠只有 −1／+1；身體、尾巴及已緩動的俯仰同一幀鏡像。移除寬度投影、最小細線、頭尾轉向延遲，不重設游動／鰭／呼吸時鐘。
- `cos(heading)` 必須越過對側 **0.20** 門檻才翻；中間區域維持原側。翻完鎖定 **0.25 秒**，以實際 delta 計時，暫停也會凍結鎖定。
- 不寫入 actor 位置、simulation 或存檔；維持原有像素 pivot 對齊。新魚仍未整合，舊三種魚保留等待 backend。

## 驗證／待核可

- 前端 **341 checks** 全綠：frontend 80、reef_animation 61、low_pixel_transitions 40、aquascape 12、swimmers 103、mirror_turn 45。已取代舊的紙片寬度連續測試。
- `test_mirror_turn` 驗證慢轉只翻一次、90° 附近左右抖動不翻、短時間反向被鎖定、鎖定後可正常反向、暫停、初始朝左、位置固定、30／60 FPS 與整數畫面。
- **待使用者判斷**：`artifacts/mirror-turn-review/` 有四魚合輯 `all-fish-60fps.mp4`，以及 `green_chromis.mp4`、`yellow_tang.mp4`、`purple_firefish.mp4`、`lawnmower_blenny.mp4`。每段 8 秒、60 FPS、1.65×；左側兩次刻意轉向，右側測試 90° 附近擺動與一次確定轉向。
- 480 格實際繪製檢查：無空白格、身體沒有轉身壓窄；每條左側魚兩次翻面，右側魚只有確定轉向的一次。`flips.json` 與 `visibility-check.json` 記錄結果。
- 所有啟動皆為 `-- --qa`。未修改 backend、生態測試或 FPS 切換政策。

```sh
godot --headless --path stream --script tests/test_mirror_turn.gd -- --qa
godot --path stream --script tools/mirror_turn_review.gd -- --qa
python3 stream/tools/verify_mirror_turn_frames.py # Pillow、numpy；可用 bundled Python
ffmpeg -y -framerate 60 -i stream/artifacts/mirror-turn-review/frames/frame-%04d.png -vf scale=1280:720:flags=neighbor -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart stream/artifacts/mirror-turn-review/all-fish-60fps.mp4
```
