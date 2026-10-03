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
