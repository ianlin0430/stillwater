# Fish-only：Claude 後端接手

2026-09-23 使用者最新指示：**「不要蝦子 魚就好」**。這項決定取代先前蝦精緻化、抱卵、蝦族群驗收與待核可要求；不要再請使用者選蝦素材。

## Codex 已做（前端）

- Stage 只呈現 threadfin / hatchet；garden_eel 仍是先前已規劃的魚，獨立 rig 尚未完成，因此不是把它畫成其他魚。
- 舊 snapshot 的 shrimp 不渲染、不接受選取、不列入畫面數量；環境不讀取牠的速度，沒有隱形蝦帶動植物或尾流。
- 蝦 birth/arrival/death/dispersal/molt/berried 都不演出；魚的出生、移入、死亡與漂走保留。
- main.gd 只有前端接線變更：選取 guard、Tab 的可見魚列表、HUD 顯示「fish in view」。沒有修改 persistence、lifecycle、simulation、QA 腳本時序或存檔。
- 舊蝦 rig / 候選 / 圖片保留為歷史工作，不再整合。正常 app 不載入候選。

## Claude 請完成（尚未做）

1. 開局不 spawn shrimp，繁殖／遷入不再建立 shrimp；保留既有魚類。不要自動增加魚數來填滿已過時的魚蝦合計目標；先沿用目前魚的初始數量。
2. 移除現存存檔的蝦要走明確遷移：記錄 departure、保留 archive 和 lineage 資訊、正確計入輸出物質，不能靜默刪掉；取消尚未孵化的蝦 brood，不補生成幼蝦。其他魚的 id/name/lineage 不變。
3. 舊檔仍可驗證／載入，歷史蝦事件可保留日誌；重新開啟不重複移除或重複計帳。先用副本驗證，不直接改使用者正式存檔。
4. 依無蝦的新模型檢查資源、物質守恆與魚族群穩定性。修訂與蝦有關的測試及舊 population 指標，明確說明語意變更；不要沿用「三／四物種都存在」的舊結論。
5. 更新離開摘要、QA 固定 shrimp 選取腳本（main.gd 約第 500 行）、採樣報表及 backend 契約，避免 QA 選到已不存在的 id。前端對不可見 id 已有 guard。
6. 移除完成後提供短測試輸出與 commit，之後仍等前端最終交付才做一次 30 分鐘驗收與版本化打包。

目前只是前端已移除蝦，**不等於後端與正式 app 已完成 fish-only 交付**。正式包尚未重打，舊存檔未動。

## 本次測試變更

`test_frontend` 將通用生命事件 fixture 改用 threadfin。退休 5 個蝦脫殼／抱卵呈現斷言，以「魚不產生殼／卵」及 7 個 fish-only 防回歸檢查替代；瞬移步足檢查改驗證魚的位置直接跳位。動作平滑與純讀取檢查保留。

實測：test_frontend 57 checks / 0 failures；test_presentation 26 / 0。
