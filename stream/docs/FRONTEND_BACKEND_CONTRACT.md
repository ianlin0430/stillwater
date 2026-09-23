# 前後端分工與快照契約

更新：2026-09-23。使用者最新決定：**環境會反應，不用照顧**。Codex 負責前端，Claude 負責 backend。不加入餵食、種植、資源消耗型玩家操作。

## 擁有範圍

Codex：`stream_stage.gd`、`stream_habitat.gd`、`stream_motes.gd`、`stream_water.gdshader`、`swimmer_rig.gd`、`fish_motion.gdshader`、`assets/`、前端測試與展示場景。

Claude：`stream_world.gd`、`stream_store.gd`、`scripts/absence.gd`及其他存檔/生命週期 helper、生態測試。`main.gd` 為接線檔，請局部修改，不覆蓋整份。Codex只修改 `_scene_input` 與操作提示，不改Claude新增的 persistence-QA、absence 或儲存程式。

原 `NON_ART_CLAUDE_PLAN.md` 的工程待辦可參考，但請以檔案目前內容為準：Claude已開始加入persist-QA與absence修復，不要把已完成的工作當成未做。前端環境互動與美術後續由Codex承接。

## snapshot v1（與world存檔版本無關）

傳入 `StreamStage.apply_snapshot(value)`，只讀；不得傳可呼叫的world或RNG物件。

- `animals: Array[Dictionary]`：每隻 `id:int`, `species:String`, `x/y:float`，世界範圍1280×720；`direction:float`, `activity:String`, `age:float`, `sex:String`, `shelter:float` 供既有rig；`vx/vy:float` 可選，缺少視為0，用來帶動水草與短尾流。
- `resources: Dictionary`：既有 `stem`, `floating`, `biofilm`, `detritus` 的非負有限數值。前景水草高度/葉量、浮葉數量、苔蘚覆蓋與落葉讀取它們，平滑過渡；缺欄位沿用前值，NaN忽略。`nutrients`、`microfauna`目前沒有獨立數量圖示，不要宣稱所有池都視覺化。
- `events`、`archive`、`next_event`、`relocated_at`：以 [BACKEND_SNAPSHOT_EVENTS.md](BACKEND_SNAPSHOT_EVENTS.md) 為準。前端只播放游標之後的 live 事件；首次載入或游標回退不重播歷史。沒有捕食演出。

## 已接上的前端互動

- 點空白水域產生局部水紋；按住左鍵拖曳持續撥水，最多24個短暫效果。
- 拖過前景植物時枝葉偏移並平滑回位；附近動物的velocity也帶動枝葉。
- 水面水紋帶動獨立浮葉；魚蝦移動留下短暫尾流，蝦Grazing顯示少量覓食碎屑。
- 點動物仍優先選取，捲輪仍縮放。letterbox外不接受場景點擊，縮放後互動位置正確換算。
- 暫停時不接收新的環境觸碰；delta=0凍結環境。隱藏時依既有renderer suspension停止更新。
- 效果不改變動物軌跡、飢餓、繁殖、資源或存檔；沒有需要backend處理的滑鼠生態指令。

植物前景是獨立繪製層，背景遠景依舊是繪圖。不要把前景近似映射當作完整植物個體模擬。觸碰的彎曲是呈現狀態，無需持久化；真正生物量仍以backend資源值為準。

## backend請維持

`advance_live`、`advance_offline`、`snapshot`、save/load仍由既有世界與store負責。回傳snapshot不得依選取/zoom/viewing light改變內容。速度必須與位置一致；瞬間重定位時前端抑制長尾流。新活動名稱要告知前端，不能只改字串造成既有動畫mapping失效。

## 測試

`godot --headless --path . --script tests/test_frontend.gd`

檢查涵蓋觸碰反應、暫停、效果上限/過期、resource讀取、縮放座標、互動開關，並逐byte驗證世界/RNG不被前端修改。這不是正式包完整CPU驗收；新增前景繪製需另測。

## 前端進度 2026-09-23（計畫 §0、§1）

已接事件游標、live 過濾、首次／游標回退／seed 更換重設。自然死亡從 archive 取外觀，事件位置兩秒沉降淡出後移除，最多保留 24 個；消失卻無死亡事件照常移除。relocated_at 或補算時間跳躍抑制尾流。snapshot 在 stage 內深複製。

驗證：test_frontend 35 checks / 0 failures；test_presentation 26 / 0；test_swimmers 103 / 0。這些是短 headless 檢查，尚未完成 §2 真實事件截图與視覺驗收。沒有跑長模擬或正式效能驗收。

後續：§2 出生、移入、漂走、空殼與抱卵演出及真實 scenario 證據；§3 蝦比較圖；§3.5 花園鰻比較圖。花園鰻 backend 已在工作目錄出現，但新 rig 尚未經使用者核可，因此 stage 暫不繪製該物種，避免被通用魚 rig 畫成斧魚。其生態資料不變。Claude 請勿把目前前端標成花園鰻已完成，也尚不應跑最終 30 分鐘驗收或正式交付打包。
