# 給 Claude：2026-10-03 核可後正式場景接線

依 `CODEX_START_HERE.md` 最上方 2026-10-03 指令執行。程式／資料 commit：**e1ec70c**（main，只包含這次修改的 6 個路徑）。

## 1. 正式舞台 v2：已完成

`StreamStage` 現在共用 `ReefSceneView`，透過 `ReefScene.background()` 載入礁岩 background-v2 或沉船 shipwreck-background-v2；正式 scripts/scenes 已無 v1 背景／裝飾引用。12 款 catalog 本來就指向 v2，現在正式舞台會依槽位實際載入。素材歷史檔保留。

`ReefSceneView.configure()` 讀取 `snapshot.decor[scene_id]`；舊 snapshot 沒有 decor 時用場景預設值。合法空槽不畫、必備槽的空／未知款式回到預設值；相同 snapshot 不重建裝飾，因此動畫不會每 0.2 秒歸零。裝飾後層 z=0、魚 z=1、裝飾前緣 z=3；兩場景共用 water shader、motes、CanvasModulate 與 nearest 過濾。delta=0 凍結裝飾。

正式舞台的舊 `StreamHabitat` ground art（固定 ROOTS 水草、固定礁岩藻斑、固定床面碎屑）停畫，避免疊在新版場景和錯誤地形上；水面漂浮物與水波／魚尾流保留。沒有修改模擬或資源帳本。

## 2. 沉船 roam 範圍：已完成，需要 Claude 重跑 S5

**唯一座標資料變更：`data/scenes/shipwreck.json` 的 `bounds.roam_x` 從 `[340, 1000]` 改為 `[340, 1150]`。** rock_spots 維持 `(492,540)`、`(1052,518)`、`(1118,568)`，仍貼原圖岩邊；床面、障礙、槽位、水層、decor.json、reef.json 都沒改。三個岩點現在都在水平 roam 範圍內；原場景測試 122 checks 不改門檻，全綠。

請讓 S5/S5-fix 使用這份沉船 JSON 重跑障礙／繞行與 home 可達性驗證。本次只有前端與場景幾何檢查，**不宣稱 backend 的完整路徑可達性已驗收**。附 `artifacts/scene-overlay/shipwreck.png`；reef 疊圖也已重產，資料未變。

## 3. 沉船花園正式場景：美術與舞台接線已完成；切換操作需要 S11

沉船正式視覺資源已接進實際 `StreamStage`，snapshot.scene=shipwreck 即載入背景與預設 pink anemone／kelp／wreck bow。也支援每場景獨立裝飾 map，切回時讀該場景選項。這不是另建的預覽舞台。

main 尚未合併 S4，且 `world.set_scene()` 的正式 S11 搬家 API 尚未可用，因此這次不加會造成地形／world 不一致的 UI 切換。原 0.75 秒淡出／淡入工具與 visual.tscn 可繼續共用。S11 落地後仍應在全黑時呼叫 set_scene、讀 relocation snapshot，再淡入；正式魚搬家與按鈕待該 backend 交接。H5 rig 仍未接正式 stage，等待 S6–S8。

QA 實際 app 截圖（四魚只替換給 stage 的 presentation snapshot，不修改 world）：

- `artifacts/production-scene-review/reef-app.png`
- `artifacts/production-scene-review/shipwreck-app.png`
- 同目錄 `reef-stage.png`、`shipwreck-stage.png` 為 640×360 原生邏輯 viewport。

截圖標記 QA／四魚 fixture／backend S4 pending，不把 fixture 當成已驗收的自然行為。所有啟動皆有 `-- --qa`，app 回報 `mode=qa path=(none)`。artifacts 是 gitignored 本機輸出，可用下面工具重產。

## 4. H5 海馬接觸點：已對齊決定

`hitch_x/y` 是**尾巴接觸點**，中心在其上方，fixed body offset 由前端素材決定。既有 H5 fixture 無需修改，`test_h5_review` 22 checks 全綠。請 S7 依此語意出正式欄位與 trace，不再用「身體中心在勾點下方」的舊草案。

## 驗證與邊界

12 組共 **811 checks 全綠**：frontend 80、cast_transition 50、stage_scenes 41、scene_data 122、decor_art 75、h5_review 22、reef_animation 53、new_fish_art 37、mirror_turn 76、low_pixel_transitions 40、aquascape 12、swimmers 103。新增 stage_scenes 驗證實際舞台背景／裝飾、重複 snapshot 不重置、暫停、輸入唯讀、分場景選項與三個沉船岩點的水平範圍。沒有放寬門檻。

```sh
godot --headless --path stream --script tests/test_stage_scenes.gd -- --qa
godot --headless --path stream --script tests/test_scene_data.gd -- --qa
godot --headless --path stream --script tests/test_decor_art.gd -- --qa
godot --path stream --script tools/production_scene_review.gd -- --qa
godot --headless --path stream --script tools/scene_overlay.gd -- --qa --scene=all
```

未合併 S4、未移除 tang/firefish/blenny、未改 CI、stream_world.gd、stream_store.gd、reef_scene.gd 或生態測試，未做長時間本機模擬。原有未追蹤 uid/import 檔未納入提交。交接記錄在 repo 內，未發送其他聊天訊息。

---

## 以下為上一輪交接歷史（畫風核可與 stage 狀態以上方為準）

# 給 Claude：S4 測試修正與前端預覽

## S4 合併前測試：已完成

main commit **3116c93** 只改 `tests/test_frontend.gd`，可單獨取用。

在隔離 checkout 的 `s4-cast-swap`（當時 HEAD **c87f229**，包含 S4 與後續 S5）重現原錯誤：一般版 0 格、jittered 版 5 格穩定巡游樣本。新陣容的 burst/glide 不適合當固定速度插值驗收的輸入；海馬自然巡游又低於原本 >8 px/s 的取樣下限。

修正為受控的 chromis snapshot：20 px/s、同深度直游、遠處目標；沿用真實 world 的 5 Hz tick／remainder 與 main 的 render cadence。只改傳給 stage 的副本，不更動 backend 的物理常數與自然行為。測試不再把自然游動是否足夠平穩當作前端速度插值的前提。

**所有門檻原封不動**：速度 >8、連續 13 格變化 <3%、至少 60 格、rendered/true 0.75–1.25。一般與 jittered 各得到 288 格，ratio 1.00–1.00；main 舊陣容與分支新陣容各 **80 checks 全綠**。未合併 S4，也未移除 tang/firefish/blenny 或改 CI。

```sh
godot --headless --path stream --script tests/test_frontend.gd -- --qa
```

## H1／美術／H5／場景

詳見 `REDESIGN_2026-09-29_REVIEW.md` 最新交付段落。新風格總覽仍待使用者核可。礁岩 JSON 更新後，scene tests 122、decor art 75、H5 review 22 全綠。沒有改 `stream_world.gd`、`stream_store.gd`、`reef_scene.gd`、場景測試或生態測試。

- 海葵容量各 3、每款必備植物 4 勾點、每場景 3 岩點，沒有減少。
- 新圖與魚共用 2 世界單位的邏輯渲染格；BODY 沿用 PROVENANCE 的 68×39 / 69×44 / 37×61 / 68×37 保守尺寸。
- 合併新座標後請讓 S5 使用這份 JSON 重跑幾何／繞行驗證；前端沒有代替 backend 宣稱自然行為已驗收。
- **H5 支點語意需對齊**：目前海馬素材的尾捲在身體下方，`hitch_x/y` 是尾巴接觸點；fixture 由該點減掉 art grip offset 得到身體中心，故中心在支點上方。草案「身體中心在勾點下方」與這張已核可直立素材相反。請 S7 明確使用尾巴接觸點，或協調固定 body offset；前端不會把這個差異寫回 world。
- 三魚的新行為只在 review fixture 中，production stage 不引用 H5 rig。正式 H5 請等 S6–S8 欄位及 traces；正式切換請等 S11，在全黑時呼叫 set_scene、讀 relocation snapshot，再淡入。

這是 repo 內交接紀錄；本次未對其他聊天或外部服務發送訊息。
