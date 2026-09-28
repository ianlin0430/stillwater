# 沉船海藻花園 · 第一版動態預覽

2026-09-27：依使用者逐項選定的方向，先交可運行預覽，尚未取代正式世界。

## 已完成

- 1280×720（16:9）、30fps、24 秒實際 Godot 畫面：`artifacts/aquascape-preview/shipwreck-garden-v1.mp4`。
- 左沉船／右拱洞／中央沙地的獨立無魚背景，粗化礁石與沙地像素；素材、原始 prompt、來源見 `assets/aquascape/PROVENANCE.md`。
- 11 叢植物：長帶藻、红色枝狀藻、低矮海草，包含後景與前景。共享缓慢变化水流，加上每叢延遲和偶爾較強的水流；根部固定。
- 周邊魚的位置與速度驅動有上限的彎曲，魚離開後由阻尼彈簧回復。輸入資料深拷貝，沒有 simulation／存檔寫入。
- 沉船旁少量上升氣泡、船艙間歇冒泡、水面小波紋；水面光紋、沙地光影和低對比光束緩慢變化。硬礁岩不扭動。
- 與背景取樣對齊的沉船／拱洞前景遮擋片。展示魚可從拱洞游出，也能在船側短暫被遮住；海草在魚前後分層。
- 預覽的 `action_tempo=1.25`：跳躍、鑽洞、姿勢追隨約縮短至原來 80% 時間，巡游位置速度不受它影響。2026-09-28 已同步正式 rig 預設為 1.25。
- 空白鍵暫停、Esc 離開；delta=0、隱藏、最小化停止預覽更新。

## 運行與重建

在 repo 根目錄：

```sh
godot --path stream res://scenes/aquascape_preview.tscn -- --qa
godot --path stream --script res://tools/record_aquascape.gd -- --qa
ffmpeg -y -framerate 30 -i stream/artifacts/aquascape-preview/frames/frame-%04d.jpg -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart stream/artifacts/aquascape-preview/shipwreck-garden-v1.mp4
```

獨立場景沒有載入 main、StreamWorld、store 或正式世界。錄製由固定 1/30 秒步進，預覽運行由真實 delta 驅動。

## 未完成／需要 backend

- **展示路線不是生態尋路**：本次目的是評估整缸動態節奏。魚繞船、穿洞使用可重播路線；正式世界要用新的造景幾何更新障礙、可游通道、床面、停棲面、啃食接觸點與洞口配置，才可接入。不能把此影片當作 backend 已理解沉船與拱洞的證據。
- 本次沒有修改 `stream_world.gd`、`stream_store.gd`、`absence.gd` 或生態測試，也沒有更换正式 main scene 的背景。
- 動態幅度、像素一致性、氣泡量及整體豐富程度仍待使用者看預覽確認。正式世界整合、長跑效能驗收未完成。

## 驗證

`test_aquascape` 12 checks：全部通過，包含凍結、隱藏停止、植物回彈與根部不漂移、輸入不變、跨狀態位置連續、展示路線真的觸發植物反應。

回歸：`test_reef_animation` 61、`test_low_pixel_transitions` 30、`test_frontend` 80、`test_swimmers` 103、`test_presentation` 29，均無失敗。

完整錄影與截圖在 `artifacts/aquascape-preview/`，錄製資料在 `capture.json`。

30 秒獨立場景 smoke check：正常退出、無引擎錯誤；暖機後平均 CPU 3.91%（一核心=100%）、最高 RSS 263.25 MiB。這是開發場景短測，不是打包版或正式 30 分鐘驗收。完整樣本在 `runtime-performance.json`。

## 2026-09-28 · 選定 B

已換成 B 方向的 v2 背景：水色偏青綠、砂地與石面減少碎紋，植物的葉片／分枝加寬並統一低飽和配色。泡泡、水光、共用水流、魚靠近植物的反應仍在。

最新獨立預覽：`artifacts/aquascape-preview-b/shipwreck-garden-b.mp4`（16:9、24 秒、30fps）。`comparison.png` 上為上一版、下為 B，都是引擎同時間截圖。重錄時加 `-- --qa --output=res://artifacts/aquascape-preview-b`，保留上一版產物。

正式世界仍使用原礁岩地形。沉船／拱門的生態整合需要 backend 配合；本次沒有把展示路線當作正式尋路。
