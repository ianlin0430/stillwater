# 2026-09-28 重新定案：後端實作計畫（Claude）

> 依據：[REDESIGN_2026-09-28.md](../REDESIGN_2026-09-28.md)（以下簡稱「定案」）。本文件只是計畫，**寫的時候沒有改任何程式碼**。
> 每一片（slice）都是：先寫會失敗的測試 → 實作到綠燈 → 真的跑過指令 → 一片一個 commit。
> 識別字、檔名、指令保留英文，其餘用中文。行號是 2026-09-28 `e27aacb` 當下的 `stream/` 內檔案。

## 0. 一眼看完

- 新陣容：`green_chromis`（留）、`clownfish`、`seahorse`、`royal_gramma`。拿掉 `yellow_tang`、`purple_firefish`、`lawnmower_blenny`，以及所有更舊的 legacy 物種與升級路徑。
- 兩個場景（`reef`、`shipwreck`），同一群魚、同一份存檔。場景的地形、槽位、裝飾效果寫在 **JSON 資料檔**，前後端共用、測試會檢查。
- 四種魚都吃同一個食物池（`microfauna`），這是最大的生態風險：**預探測已經看到會餓**（見 §4.2），要先量再定數字。
- 「不會餓死、不會死光」要做成**機制保證**，不是靠數字運氣；再用寬 seed 清單驗證它平常也不會貼著底線過日子。
- 老死：離線時直接記帳；即時畫面裡，死掉的魚變成一個不參與生態的「離場身影」（`departing`），游到邊緣或裝飾後面，前端淡出。
- 存檔：新格式 `version 3`、新檔名，舊檔不讀也不碰。
- FPS 60／30／不畫：Claude 寫一個小的 `FramePacer`，`main.gd`（前端）只加呼叫；需要 Codex 配合的介面列在 §5.4 和 §9。
- 分片共 16 片（§7），每片都寫了第一個失敗測試、完成指令與交接點。

---

## 1. 現況盤點

### 1.1 `scripts/stream_world.gd`（1677 行，後端核心）

| 項目 | 位置 | 處置 | 理由 |
|---|---|---|---|
| `VERSION=2` | :4 | **改** 3 | 全新世界、新格式。 |
| `MAX_ANIMALS`、`MAX_AWAY`、`DAY` | :5–7 | 沿用 | 與魚種無關。 |
| `ACTIVE_SPECIES` | :8 | **重寫** | 換成新四種。 |
| `SPECIES` | :9–26 | legacy 5 種（:12–17）**刪**；blenny :19、firefish :22、tang :26 **刪**；chromis :23 沿用；**新增** 3 種 | 定案拿掉舊魚。新魚數值由探測決定（§4）。 |
| `CAP` | :33 | **重寫** | 由探測決定。 |
| `REEF_CAST` | :35 | **刪** | 只給舊存檔用。 |
| `POOLS`、`OPENING`、`PLANTS`、`K_NUTRIENT`、`MICRO`、`DECAY`、`STREAM_OUT` | :36–47 | 沿用 | 物質帳本與植物不動。 |
| `STREAM_IN` | :46 | 保留結構，`microfauna` 數值**待探測** | 四種魚都吃 microfauna（§4.2）。 |
| `DEPTH`（水層） | :49 | **搬進場景檔** | 每個場景可能不同。 |
| `CHROMIS` | :57 | 沿用 | 魚群規則不變。 |
| `RESCUE_AT`、`RESCUE_RATE`、`ARRIVAL_RATE` | :60, :65–66 | 保留，救援改成「必到」（§4.3） | 定案「不會死光」。 |
| `OPENING_AGE` | :64 | **重寫**（每種魚一組） | tang 那組刪掉。 |
| `RELOCATION` | :71 | 沿用 | 切場景時會用到 `relocated_at`。 |
| `FIRE_BURROWS`、`FIRE`、`HOMES` | :79–82 | **刪** | 「家」改由場景檔的海葵／勾點／洞口提供。 |
| `FOOD` | :90 | 沿用；`eel_dx`/`eel_reach` 改名成通用的「就近搶食」欄位；`surface` 改從場景讀 | 名字是花園鰻留下的。 |
| `STARTLE` | :93 | 沿用；`eel_seconds` 改名 `hide_seconds` | 同上。 |
| `LURE` | :97 | 沿用 | 定案保留游標引魚。 |
| `BLENNY` | :105 | **刪** | |
| `BODY` | :108 | **重寫** | 新魚的圖尺寸要 Codex 給（交接點）。 |
| `SWIM` | :129–132 | chromis 沿用、tang **刪**、新增 3 種 | |
| `SEPARATE` | :133 | 只留 `margin/look/gain/close`，其餘 tang 專用的 **刪** | |
| `TANG` | :149 | **刪** | |
| `NAMES` | :150 | **重寫** | |
| `_init` | :173–208 | **重寫**開場擺位（依場景的家） | 現在寫死 chromis/tang 座標。 |
| `floor_y`（static） | :210–211 | **改**成讀場景床面曲線 | 前端 `main.gd:295`、`stream_events.gd:61` 在用（交接點）。 |
| `animal_scale` | :213 | 沿用 | |
| `_place` | :217–224 | **重寫** | 依物種在場景裡找位置。 |
| `spawn` | :226–243 | **改**：拿掉 `next_molt/molting_until/shelter`（:233），家的指派改通用 | legacy 欄位只為舊檔存在。 |
| `_bed_align` | :246–253 | **刪**（出生／移入位置改由家決定） | 只為 blenny。 |
| `_event` | :256–276 | 沿用 | 事件契約不變。 |
| `advance_live`、`advance_offline`、`catch_up` | :278–321 | 沿用 | 時間與離線上限不變。 |
| `feed` | :325–349 | 沿用（x 範圍從場景讀） | |
| `startle` | :352–383 | **重寫**各物種反應 | 定案：受驚散開、躲進裝飾。 |
| `set_lure`、`clear_lure` | :386–398 | 沿用 | |
| `_sink_food` | :400–409 | 沿用（床面從場景讀） | |
| `_seek_food` | :412–439 | 沿用給 chromis，拿掉 tang 的輪流邏輯（:415–424） | |
| `_eat` | :443–452 | 沿用，拿掉 `chew_until`（:448–449） | |
| `_move` | :464–669 | **重寫**成「依物種分派」；chromis 那條路徑沿用，tang 相關（:490–505、:519–561、:594–613、:626–669 的 tang 分支）**刪** | 205 行裡大半是 tang。 |
| `_swim` | :676–743 | **沿用**（自然游動核心：heading/pitch/speed/thrust/turn） | 四種會游的魚都用它。 |
| `_gives_way` | :747–753 | **刪** | 兩隻 tang 之間用。 |
| `_body` | :755–757 | 沿用 | |
| `_avoid` | :760–810 | **簡化**＋**加障礙物** | 拿掉 tang 讓路，加入裝飾障礙物（§3.2）。 |
| `_off_grazing_tangs`、`_stuck`、`_off_stuck_chromis`、`_around` | :815–986 | **刪**（約 170 行） | 全為 tang。 |
| `_tang_contact`、`_tang_hold`、`_choose_tang` | :988–1044 | **刪** | |
| `_hash01` | :1047–1052 | 沿用 | 不抽 RNG 的排程。 |
| `_burrow` | :1055–1071 | **改寫**成通用 `_assign_home()` | 概念（找最近空位）可用。 |
| `_burrower` | :1075–1108 | **刪**；`extend` 0/1 的寫法給 royal_gramma 參考 | |
| `_blenny`、`_choose_blenny`、`_hop`、`_burrow_at`、`_clear_of_burrows`、`_peck` | :1111–1234 | **刪** | |
| `_follow`、`_choose_activity`、`_look`、`_roaming_x` | :1237–1303 | 沿用（x 範圍與夜間休息點從場景讀） | |
| `natural_light`、`sub_light`、`biofilm_max`、`_excrete` | :1305–1316 | 沿用 | |
| `_ecology` | :1318–1407 | 沿用骨架；**改**餓死（:1390）與老死（:1396） | §4.3、§4.4。 |
| `_food_tick` | :1409–1417 | 沿用 | |
| `_breed` | :1419–1434 | 沿用；`_bed_align`（:1433）換成家的指派 | |
| `_remove` | :1436–1453 | 沿用；老死時另外產生離場身影 | |
| `_migration`、`_arrive` | :1455–1473 | **改**：救援必到；移入位置（:1470）改從場景出入口 | |
| `_sample`、`habitat_cap`、`counts`、`material`、`residual`、`snapshot`、`events_after` | :1475–1516 | 沿用 | |
| `export_state` | :1518–1522 | 沿用 | |
| `restore` | :1524–1560 | **大幅刪減**：拿掉 v1 升級（:1539–1540）、移除物種離開（:1544–1547）、`reef_cast` 開場（:1552–1559） | 定案：舊格式不轉換。 |
| `_upgrade_v1` | :1563–1572 | **刪** | |
| `validate` | :1574–1649 | **重寫**：只收 `version==3`；拿掉 `eel_colony/reef_cast`（:1587）、v1 的 resources 分支（:1603）、legacy 必要欄位 `next_molt/molting_until/shelter`（:1610）、`brood_until/tint`（:1614–1616）、`garden_eel/purple_firefish` 洞口（:1617–1620）；**新增** `scene`、`decor`、`departing`、各物種的家欄位 | |
| `_valid_food`、`_number`、`_valid_event` | :1651–1677 | 沿用 | |

小結：約 1677 行裡，tang／blenny／firefish／legacy 相關大約 700 行會刪；`_swim`、魚群、生態、存檔、時間、帳本這些已驗證過的核心**全部沿用**。

### 1.2 其他後端腳本

| 檔案 | 現況 | 處置 |
|---|---|---|
| `scripts/stream_store.gd` | 原子存檔＋SHA-256＋`.bak` 輪替（:11–33）、讀取（:35–48）、`load_or_create` 讀不到時另存 recovery（:50–73）。`DEFAULT_PATH="user://stream.world"`（:3），格式字串 `"stillwater-stream-1"`（:18, :42）。 | **沿用**邏輯；**改** `DEFAULT_PATH` 成新檔名、格式字串成 `"stillwater-reef-3"`（§5.2）。 |
| `scripts/absence.gd` | 離開期間分段補算、合併成一次摘要（:9–21）；文字 `"hours of stream life"`（:26）。 | 沿用；文字改 `reef life`（小改，放在 S3）。 |
| `scripts/persist_qa.gd` | `--persist-qa` 隔離目錄、摘要、digest、`lost()`（:1–47）。`summary()` 只讀 id/name/parent/species（:17–18）。 | **沿用**不動（與魚種無關）；S11 加 `scene`、`decor` 到摘要。 |
| `tools/cast_probe.gd` | 離線探測：用 JSON 替換 `ACTIVE_SPECIES/CAP/SPECIES/NAMES`（:24–56）。**已壞一處**：`rescue_at` 的替換找的是 `"if c[species]<=2 and"`（:34–35），但程式早已改成 `RESCUE_AT` 常數（`stream_world.gd:60`、:1458），所以這個選項**悄悄沒作用**。 | S0 修好，並加上可替換 `STREAM_IN`、`OPENING_AGE`。 |

### 1.3 `main.gd`（前端，Codex 的檔；工作目錄裡有 Codex 未 commit 的改動）

- 目前固定 30 FPS：`Engine.max_fps=30`（:62）、`_set_suspended_view`（:498–521）隱藏時 `max_fps=10`＋`render_loop_enabled=false`、恢復時回 30。
- 焦點：`_notification` 的 `NOTIFICATION_APPLICATION_FOCUS_OUT/IN`（:531–534）只記 `focused`，沒有拿來調 FPS。
- 隱藏判斷：`should_hide`（:444）＝最小化或 `window_can_draw()` 為 false。
- QA 前景驗收寫死 30 FPS：`foreground_30_minute_eligible` 要 `qa_drawn_frames>=50400`（:599，=28 分 × 30 fps）。
- 點魚看資訊：`stage.pick`（:288）、`_select`（:317）；說明文字（:218）還寫著「Click an animal」「Quiet mode: 30 FPS」。
- 用到後端的地方：`StreamWorld.FOOD.surface` 與 `StreamWorld.floor_y`（:295）、`StreamWorld.SPECIES`（:392）；另外 `stream_events.gd:61` 用 `floor_y`、`stream_stage.gd:86, :213` 用 `SPECIES`。這些都是交接點。

### 1.4 測試與工具

「綁死舊魚種」＝直接用 tang/blenny/firefish/legacy 物種名或其常數。

| 檔案 | 歸屬 | 綁舊魚種？ | 處置 |
|---|---|---|---|
| `tests/test_world.gd`（1438 行） | 後端 | **重度**：tang 16、blenny 7、firefish 15、legacy 71 處。第 65 行把陣容寫死；`legacy_shrimp`（:19）、`legacy_predation_save`（:27）、`shrimp_departure_checks`（:454）、`hatchet_departure_checks`（:550）、`eel_checks`（:608）、`blenny_checks`（:929）、`firefish_checks`（:1042）、`tang_checks`（:1257）、`reef_cast_checks`（:1408）；:71 legacy 不能 spawn；:164 **「Starvation remains possible」**（與新定案相反）；:212–229 crayfish 升級；:258 衍生閘門釘死 7/76/12/[12,17]。 | **重寫**。可沿用：開頭的存檔／還原／重複性／損毀復原／72 小時上限／帳本（:61–160）、`feeding_checks`（:675）、`startle_checks`（:836）、`lure_checks`（:864）、`chromis_checks`（:1186）、`ecosystem_checks`（:277）的大部分。刪掉所有舊魚種與升級相關段落、`tests/fixtures/*.var`（4 個舊存檔）改成一個「舊檔不讀、不被改寫」的檢查。 |
| `tests/test_natural_motion.gd`（771 行） | 後端 | 重度：tang 25、firefish 6。`blenny_checks`（:277）、`firefish_checks`（:322）、`tang_grazing_checks`（:344）、`encounter_checks`（:593）、`school_pass_checks`（:643）、`rest_on_rest_checks`（:698）全是 tang/firefish。 | 沿用 `kinematics_checks`（:75）、`band_edge_checks`（:171）、`feeding_checks`（:248）、`night_rest_checks`（:427，chromis 部分）、`determinism_checks`（:742）、`seeds()`（:40）；其他**刪**，新增障礙物與新魚的運動檢查。 |
| `tests/test_roaming.gd` | 後端 | 輕度（tang 1、blenny 1、HOMES）。:18–29 對 HOMES 與 blenny 的分支。 | 改寫成 chromis＋新魚的活動範圍檢查。 |
| `tests/test_presentation.gd` | 後端 | 不綁（只用 chromis）。 | 沿用；加 `departing`、`scene/decor`、切場景的 `relocated_at` 檢查。 |
| `tests/test_lifecycle.gd` | 後端 | 不綁。 | 沿用；新檔名後「真實存檔只算 hash、不被改」這條要指向新舊兩個檔名。 |
| `tests/test_persist_qa.gd` | 後端 | 不綁。 | 沿用。 |
| `tests/test_long_run_chunks.gd` | 後端 | 不綁。 | 沿用；加 `--scene/--decor` 參數後，續跑時要檢查參數一致。 |
| `tests/long_run.gd` | 後端 | 輕度：`audit_depth`（:16–32）對 HOMES／blenny 分支；`BANDS=StreamWorld.DEPTH`（:12）。其餘（tally、chunk、judge）通用。 | 改 `audit_depth` → `audit_space`（水層＋不在障礙物內＋各物種的家規則）；加 `--scene`、`--decor`；`presence` 閘門改 100%（§4.3）。 |
| `tests/ecology_acceptance.gd` | 後端 | **不綁**：全部從 `ACTIVE_SPECIES`、`SPECIES.initial`、`OPENING_AGE`、`CAP` 算出來（:9–57）。 | **沿用**，只要常數換好，閘門自動跟著變。 |
| `tests/natural_motion_trace.gd` | 後端工具 | 不綁。 | 沿用。 |
| `tests/test_frontend.gd`、`test_reef_animation.gd`、`test_low_pixel_transitions.gd`、`test_swimmers.gd`、`test_aquascape.gd`、`test_shrimp_candidate.gd` | **前端（Codex）** | 多處綁舊魚 | Claude 不改。換陣容那一片（S4）落地時，這些可能變紅，要和 Codex 排好順序（§9 H3）。 |

### 1.5 `docs/ecology.md` 的上限推導方式（沿用這套方法）

1. **先量再定**：`tools/cast_probe.gd` 用真的 `stream_world.gd`、只換陣容常數，離線不餵食跑 180 天（也跑 365 天），看：餓死數、留下的出生、漂走的幼魚、移入數、老死數、族群大小範圍、食物池最低值（ecology.md:33–60）。
2. **選擇規則**：在「食物池最低值 ≥ 損益兩平 10」「不餓死」「族群約 12–18、遠低於硬上限 24」「留下的出生 > 移入」都成立的設定裡，挑最大的那個（ecology.md:39, :56–58）。損益兩平：`cost = 0.8 × bite × f/(f+10)`，每種魚都設計成 f=10 兩平（ecology.md:25）。
3. **閘門從常數推導，而且在看結果之前寫下來**（ecology.md:98–114）：族群帶＝[開場總數, 上限總和]、必然老死數與最晚日、需要的後代數＝必然老死＋開場時空位；由 `tests/ecology_acceptance.gd` 計算，`test_world.gd` 釘住推導出的數字。**不為了過關改門檻**，過不了就改設計數字、重新探測。

### 1.6 `.github/workflows/ecology-batch.yml`

- 手動觸發，輸入 `mode/days/seeds/year/feed`（:15–35）。
- `core` job 跑 10 個測試（:95），包含前端的 `test_frontend`、`test_reef_animation`。
- 180 天拆成 3 段串接（`plan` → `chunk1` → `chunk2` → `chunk3`，:41–）；每段 60 天、以 artifact 傳 checkpoint，只有 `chunk3` 判定。每個 job `timeout-minutes: 350`（5h50m）。
- 上次實測（validation.md:518）：每段 60 天 1h23m–2h38m。
- repo 是 **public**（`ianlin0430/stillwater`），標準 runner 分鐘數不計費；免費帳號同時最多約 20 個 job。

---

## 2. 場景檔格式提案

### 2.1 用什麼格式

**建議：JSON 資料檔＋一個後端的純資料載入器。**

- 檔案：`stream/data/decor.json`（所有裝飾款式的效果，座標相對於槽位錨點）、`stream/data/scenes/reef.json`、`stream/data/scenes/shipwreck.json`。
- 載入器：`scripts/reef_scene.gd`（`class_name ReefScene`，`RefCounted`，只讀資料、不碰畫面、不抽 RNG）。提供 `ReefScene.load(id)`、`floor_y(x)`、`band(species)`、`slots()`、`effects(slot_id, style)`、`validate()`。前端也用同一個載入器讀槽位與錨點，不自己解析。
- 為什麼不用 `.tres`：綁 Godot class、diff 很難讀、不好用工具檢查；為什麼不用 GDScript 常數：Codex 要調座標時會碰到後端程式檔，不符合「不要改 `stream_world.gd`」的分工。JSON 可以 diff、可以寫 schema 測試、Python 工具也能讀。
- **要驗證的風險**：`export_presets.cfg` 用 `export_filter="all_resources"`、沒有 `include_filter`。Godot 4 會把 `.json` 當 JSON resource 匯入，預期會被打包，但**S1 要實際匯出一次確認**；不行就在 `include_filter` 加 `data/*`（那是設定檔，要先備份）。

### 2.2 座標系

沿用現在的世界座標 **1280×720**（`BACKEND_SNAPSHOT_EVENTS.md` 事件表寫的 x/y 就是這個）。像素整數倍放大與像素對齊是前端的事；後端只給浮點世界座標。**要跟 Codex 確認一件事**：低像素美術的 1 個「粗像素」等於幾個世界單位（例如 4），裝飾錨點最好落在這個格線上（§9 H1）。

### 2.3 場景檔內容（草案）

```json
{
  "id": "reef",
  "version": 1,
  "background": "res://assets/reef/background-v1.png",
  "bounds": {"x": [100, 1180], "roam_x": [130, 1150], "surface_y": 56},
  "bed": [[0, 597], [40, 599], [80, 601], "... 每 40 px 一點，線性內插 ..."],
  "bands": {
    "green_chromis": [180, 430],
    "clownfish": [300, 560],
    "seahorse": [240, 580],
    "royal_gramma": [380, 590]
  },
  "exits": [[-40, 300], [1320, 300]],
  "terrain_obstacles": [{"cx": 1010, "cy": 520, "rx": 70, "ry": 50}],
  "rock_spots": [{"x": 240, "y": 470, "side": 1}, "... royal_gramma 沒有岩洞時的退路，數量 ≥ 其上限 ..."],
  "slots": [
    {"id": "anemone", "anchor": [520, 590], "required": "anemone", "styles": ["anemone_green", "anemone_pink"], "default": "anemone_green"},
    {"id": "hitch_plant", "anchor": [880, 596], "required": "hitch", "styles": ["seagrass_tall", "gorgonian"], "default": "seagrass_tall"},
    {"id": "s1", "anchor": [300, 600], "required": null, "styles": ["cave_rock", "shell", "brain_coral"], "default": "cave_rock"},
    {"id": "s2", "anchor": [700, 600], "required": null, "styles": ["cave_rock", "table_coral"], "default": ""}
  ]
}
```

- `bed`：床面折線，取代寫死的 `floor_y()`（`stream_world.gd:210`，現在是兩個 sin 的和）。reef 場景的第一版就用現在的公式取樣，讓舊行為不變。
- `bands`：各魚的水層（取代 `DEPTH`，`stream_world.gd:49`）。數字是佔位，實際由魚的行為和背景決定。
- `exits`：老死離場時「游到畫面邊緣」的點；移入者從這裡進來。
- `terrain_obstacles`：背景本身的大石頭、船身（不是槽位，拿不掉）。
- `rock_spots`：royal_gramma 在沒有岩洞時的退路；**數量必須 ≥ gramma 上限**，這樣裝飾不影響上限（定案：裝飾不改變數量上限）。
- `slots`：`required` 是 `"anemone"`、`"hitch"` 或 `null`。必備槽不能清空（`""` 不合法），只能換款式。

### 2.4 裝飾款式檔 `data/decor.json`（草案）

```json
{
  "anemone_green": {
    "kind": "anemone",
    "obstacles": [],
    "anemone": {"cx": 0, "cy": -34, "rx": 46, "ry": 30, "capacity": 3},
    "shelters": [],
    "hitches": [],
    "fade_spots": [[0, -20]]
  },
  "seagrass_tall": {
    "kind": "hitch",
    "obstacles": [],
    "hitches": [[-18, -120], [6, -160], [22, -95], [-4, -70]],
    "shelters": [],
    "fade_spots": [[0, -60]]
  },
  "cave_rock": {
    "kind": "shelter",
    "obstacles": [{"cx": 0, "cy": -40, "rx": 60, "ry": 40}],
    "shelters": [{"x": 34, "y": -30, "side": 1, "use": ["royal_gramma", "green_chromis_night"]}],
    "hitches": [[-40, -78]],
    "fade_spots": [[-10, -40]]
  }
}
```

每款裝飾的效果（全部相對錨點）：

| 效果 | 形狀 | 誰用 |
|---|---|---|
| `obstacles` | 軸對齊橢圓 `{cx,cy,rx,ry}` 的清單 | 所有會游的魚繞過（§3.2）。選橢圓是因為現有 `_avoid` 就是橢圓數學（`stream_world.gd:779–785`），便宜、好測。 |
| `anemone` | 一個橢圓＋`capacity` | clownfish 的家。 |
| `hitches` | 點的清單，每點一隻 | seahorse 勾住的地方。 |
| `shelters` | 洞口點＋朝向 `side`＋`use` | royal_gramma 的洞；chromis 夜裡在旁邊休息。 |
| `fade_spots` | 點 | 老死的魚「躲到裝飾後面」的位置（前端要把這款裝飾的前景層畫在魚上面）。 |

### 2.5 誰填座標

1. **S1**：Claude 用佔位座標把兩個場景檔填好（reef 用現有背景 `assets/reef/background-v1.png` 大略估；shipwreck 用 `assets/aquascape/shipwreck-background-v2.png` 估），並寫 `tools/scene_overlay.gd`：把床面、水層、障礙橢圓、勾點、洞口、槽位錨點畫在背景圖上輸出 PNG，給人和 Codex 對照。
2. **對齊（定案順序第 2 步）**：Codex 出正式背景與裝飾圖後，Codex **只改 `data/*.json` 的座標**（不碰 `stream_world.gd`），Claude 跑 `test_scene_data.gd` 和運動測試確認沒壞。這個分工要 Codex 同意（§9 H1）。

### 2.6 場景資料的測試（`tests/test_scene_data.gd`，S1）

- 兩個場景都能載入，欄位型別正確，`bed` 的 x 嚴格遞增且覆蓋 0–1280。
- 每個場景恰好一個 `required:"anemone"` 槽、至少一個 `required:"hitch"` 槽；必備槽的每一款都真的有 anemone／hitches。
- **容量 ≥ 上限**（不管選哪款）：海葵 `capacity ≥ CAP.clownfish`；必備水草每款的勾點數 ≥ `CAP.seahorse`；`rock_spots` 數 ≥ `CAP.royal_gramma`。這保證「裝飾不改變上限」。
- 每個家的點（勾點、洞口、海葵中心）都在該物種水層內、在床面上方、不在任何障礙橢圓裡（任何款式組合）。
- 每個水層都有一條沒被障礙物完全擋住的水平通道（不然魚會被困住）。
- 同一場景裡各槽的障礙物在任何組合下不互相重疊到把通道封死。

---

## 3. 四種魚的後端行為

共通規則：
- 會游的魚都走 `_swim`（`stream_world.gd:676`），前端照舊拿 `heading`（0…π 連續）、`direction`、`pitch`、`speed`、`thrust`、`turn`、`vx`、`vy`、`relocated_at`。**定案的「紙片式轉身」只用 `abs(cos(heading))`，欄位不用改。**
- `activity` 名稱是前端的契約，新名稱列在下面。
- 每一種魚的「家」是一個欄位 `home`：`{"kind":"anemone|hitch|shelter|rock|school","slot":"<slot id 或 ''>","i":<序號>}`＋家的座標 `home_x`、`home_y`（存進存檔、`validate` 檢查；前端可用來畫對位）。
- 互動（餵食、敲玻璃、游標）只改短期移動，不改能量以外的生態，**不存檔**，和現在一樣（ecology.md:128）。

### 3.1 各物種

**`green_chromis`（沿用現有魚群）**
- activities：`Schooling`、`Resting`、`Feeding`、`Startled`、`Curious`（只有領頭魚）——不變。
- 改動：夜裡領頭魚選 `Resting` 時，若附近（例如 300 px 內）有 `shelters` 且 `use` 含 `green_chromis_night`，就在洞口旁邊（外側 40–60 px）休息，否則就地休息（現行 :1265–1269）。障礙物繞行（§3.2）。
- 敲玻璃：沿用散開再聚回（:375–382）。
- 事件：沿用。

**`clownfish`**
- 家：場景唯一的海葵（`anemone`），`capacity` 內大家共用。
- activities：
  - `Nestling`：在海葵橢圓內小幅來回扭動（目標點在橢圓內輪流換，距離 10–30 px，慢速、短滑行）。
  - `Foraging`：離開海葵一小段（≤ 120 px、在自己水層內）去看看，時間到或吃到就回。
  - `Sheltering`：受驚或游標太近時鑽進海葵（目標是橢圓中心），停留 `hide_seconds`。
  - `Sleeping`：夜裡窩在海葵裡（幾乎不動）。
  - `Feeding`：追海葵附近 `notice` 範圍內的飄落飼料（範圍比 chromis 小，吃完回家）。
- 給前端：共通欄位＋`nestle`（0…1，目標值，1＝深埋在觸手裡，前端決定畫在觸手前或後、平滑過渡；仿 firefish 的 `extend`）。
- 裝飾互動：海葵換款式時，家的座標跟著換（`home_x/home_y` 更新，魚自己游過去，不瞬移）。

**`seahorse`**
- 家：一個勾點（必備水草或任何有 `hitches` 的裝飾），一點一隻。
- activities：
  - `Hitched`：尾巴勾住，位置固定在勾點下方一點（身體中心＝勾點＋固定偏移），`vx=vy=0`；身體輕輕搖（backend 給 `lean`）。
  - `Drifting`：放開，直立慢慢漂到另一個空勾點（速度 3–6 px/s、幾乎不轉身，路徑略帶上下起伏），到了轉成 `Hitched`。多久放開一次：白天平均幾分鐘一次，夜裡不動。
  - `Feeding`：只在 `Hitched` 時，飼料飄到吻部附近（小範圍）就「吸」一口，不離開勾點（類似 firefish 的就近搶食規則 `stream_world.gd:1103–1108`）。
  - `Startled`：勾著時不逃，`lean` 收緊、`thrust` 升高一下；漂著時就近勾住最近的空勾點。
- 給前端：共通欄位（`heading` 只在 0 或 π 附近慢慢轉）、`hitch_x`、`hitch_y`（只有 `Hitched` 時存在）、`lean`（rad，身體相對垂直的傾斜，平滑、限速）、`thrust`（背鰭扇動強度，0…1，漂的時候高）。
- 裝飾互動：勾點所在的裝飾被換掉或清空 → 轉 `Drifting` 去最近的空勾點。**保證**：必備水草的勾點數 ≥ 上限，所以永遠有地方勾。

**`royal_gramma`**
- 家：一個 `shelter`（有 `use` 含 `royal_gramma` 的洞），一洞一隻；沒有空洞時用場景的 `rock_spots`。
- activities：
  - `Hovering`：在洞口外 15–50 px 內慢慢徘徊、偶爾轉身。
  - `Hiding`：進洞（`extend` 目標 0）。受驚、夜裡、有大魚群靠近時；時間到再出來。
  - `Sleeping`：夜裡在洞裡。
  - `Feeding`：飼料飄過洞口附近就衝出去咬一口再回來。
  - `Startled`：直接 `Hiding`。
  - 家是 `rock` 時：`Hiding` 變成「貼著岩石邊不動」，`extend` 仍給 0.3 左右，前端畫成縮在石頭邊。
- 給前端：共通欄位＋`extend`（0…1 目標，0＝在洞裡看不到、1＝出洞）、`den_x`、`den_y`（洞口點）、`den_side`（洞口朝向）。
- 裝飾互動：洞被換掉／清空 → 家改成最近的空洞或 `rock_spot`，游過去。

### 3.2 障礙物（裝飾「繞過而不是穿過」）

- 障礙＝場景 `terrain_obstacles` ＋ 目前所有槽位款式的 `obstacles`（換裝飾時重算快取，不存檔）。
- 三層做法，全部在 `_move` 的每個 0.2 秒 tick：
  1. **目標不放在障礙裡**：選目標時若落在（障礙橢圓＋半個身體）裡，推到橢圓外緣（像 `_off_grazing_tangs` 的做法，:815–830）。
  2. **看前方繞行**：直線路徑會穿過障礙時，加一個「從上方或下方繞」的轉向（選升降較少、水層放得下的一側，選了就整段不換邊），平滑加入（參考 tang 繞 chromis 學到的：轉向變化要限速，不然會抖）。
  3. **硬保險**：移動後若身體中心還在障礙橢圓裡，投影回外緣；正常情況下這一步位移 < `RELOCATION` 3 px，不標記重定位。
- 例外：clownfish 在自己的海葵、gramma 在自己的洞口、seahorse 在自己的勾點——那是「家」，不算障礙。
- 驗收：中心**永遠**不在任何障礙橢圓內（硬條件，0 次）；身體框與障礙重疊比例 ≤ 0.2（軟條件，與現有 tang 門檻同級，`test_natural_motion.gd` 的做法）；繞行時每 tick 速度變化有上限（不抖）。

### 3.3 事件

沿用現有種類（`begin/birth/dispersal/arrival/death/ate/fed`），新增：
- `death` 多一個選填欄位 `leaving: true`：只在**即時**老死、產生離場身影時。
- 不新增「躲藏」「勾住」之類事件；那些由 `activity` 表達（事件表維持精簡，前端已經靠 `activity` 做動畫）。
- 切場景、換裝飾：**不產生事件**（不進日誌）；只在 snapshot 的 `scene`、`decor` 改變，並標 `relocated_at`（§5.1）。

---

## 4. 生態

### 4.1 食物池

- 沒有再啃藻的魚：`biofilm` 不再被任何魚吃。**建議保留** 6 個池子與植物模型不動（`POOLS`，:36），`biofilm` 只當植物覆蓋、自然長到上限；物質帳本、植物 >5% 閘門照舊。這是最小改動。
- 四種魚都吃 `microfauna`（浮游小生物）。chromis 本來就吃；海馬、皇家范魚、小丑魚在現實裡也都是吃浮游動物，這樣最合理。
- 因此 `microfauna` 的來源（`STREAM_IN.microfauna`＝0.35/天，:46）很可能要提高；由探測決定（§4.2）。
- 飼料：沿用（每天最多 4 撮、80% 變能量、20% 變碎屑、沉底 900 秒後變碎屑）。沉底飼料不再有人撿（blenny 走了），全部照規則變碎屑，帳本不變。

### 4.2 上限與繁殖：先量再定

**預探測（2026-09-28 寫計畫時跑的，只用來看方向，不是定案數字）**：用 `tools/cast_probe.gd` 的暫時副本（放 scratchpad，未進 repo），離線、不餵、60 天。新魚的數值是我先猜的，全部照「f=10 兩平」設計（cost＝0.4×bite）：clownfish（成熟 45 天、壽命 300、cost 0.2）、seahorse（60、300、0.16）、royal_gramma（40、240、0.16）；上限 chromis/clown/seahorse/gramma＝8/3/3/3，開場 6/2/2/2。

| `STREAM_IN.microfauna` | seed | microfauna 最低／平均 | 餓死 | 族群範圍 |
|---|---|---|---|---|
| 0.35（現值） | 42 | 4.2 ／ 10.9 | **2 隻 chromis** | 11–15 |
| 0.7 | 42 ／ 812 | 6.0 ／ 7.1（最低） | 0 ／ 0 | 12–17 ／ 12–16 |
| 1.0 | 42 ／ 812 | 9.6 ／ 11.4（最低） | 0 ／ 0 | 12–17 |

讀法：**四種魚都吃 microfauna、來源不變的話會餓死**；來源加倍還是低於兩平 10。1.0 左右才接近以前的安全邊際。這只是 60 天、1–2 個 seed，正式數字要照下面的探測流程。

**探測流程（S2，照 ecology.md 的規則；判準在跑之前寫進 ecology.md）**：
1. **判準先寫下**（不看結果）：不餵食、180 天、寬 seed 清單**每一個** seed：`floor_hits`（能量碰到下限的「隻×分鐘」，§4.3）＝0；`microfauna` 最低值 ≥ 10；族群落在約 12–18；留下的出生 > 移入；365 天時每種魚都還在。
2. **粗篩**（3 個 seed：42/812/240921）：`STREAM_IN.microfauna` ∈ {0.7, 0.85, 1.0, 1.2} × 上限組合（chromis 6–8、clown 2–3、seahorse 2–4、gramma 2–3），開場固定 6/2/2/2＝12。
3. **細篩**：粗篩前 3–5 名 × 寬 seed 清單 × 180 天。
4. **定案**：在全部 seed 都過的設定裡挑族群最熱鬧（上限總和最大）的；再跑 365 天確認。表格寫進 `docs/ecology.md`（新章節，舊章節標為 superseded），和以前一樣附每個 seed 的數字。
5. 閘門（§6.4）照 `ecology_acceptance.gd` 從新常數自動推導，並在看 live 結果**之前** commit。

每種魚的附加限制（不管探測結果如何都要成立）：
- `CAP.clownfish ≤ 海葵 capacity`（建議 3：一對＋一隻小的）。
- `CAP.seahorse ≤ 必備水草最少勾點數`。
- `CAP.royal_gramma ≤ rock_spots 數`（和洞數無關，所以裝飾不影響上限）。
- 繁殖：沿用現有規則（成熟、能量 > 0.74 reserve、冷卻、看食物的機率，:1397–1400）。幼魚出生在親代的家附近（clownfish 在海葵、seahorse 在最近空勾點、gramma 在最近空洞／岩點、chromis 在親代旁邊的水層）；滿了就漂走（`dispersal`，帳本記出）。

### 4.3 保證：不會餓死、不會死光

**不會餓死（機制，建議；要使用者確認 Q1）**：
- 目前（:1386–1393）能量不夠付代謝就 `_remove(a,"starvation")`。改成：能量有下限 `floor = 0.1 × reserve`；付不起的代謝**就不付**（不從任何池子扣，帳本仍平衡），能量停在下限，而且在下限時**不繁殖**。
- 另外記一個統計 `floor_hits`（碰到下限的隻×分鐘，存在 `state.totals`），讓測試和探測能看出「平常就貼著底線」這種不健康的情況。探測判準要求它是 0。
- `test_world.gd:164`「Starvation remains possible」改成反向：把所有池子歸零、`supply_scale=0` 跑 30 天，`causes` 裡沒有 `starvation`，帳本仍平衡。

**不會死光（機制，建議；Q2）**：
- **最後一隻不老死**：某種魚只剩 1 隻時，牠到了壽命也先不走，等同種有第 2 隻（出生或救援）才走。
- **救援必到**：某種魚 ≤ `RESCUE_AT`（1）時，排一個確定的救援時間（抽一次 `rng`，落在 2–24 小時內），不是每小時 1/96 的機率（:1458）。
- 兩個加起來，任何物種的數量永遠 ≥ 1（沒有餓死、沒有隨機離開）。長跑閘門 `presence` 從「≥95% 的天數」改成「**100%**、最長缺席 0 天」。

### 4.4 老死：游到邊緣或裝飾後面

- **離線**（`_ecology(true)`）：到了壽命就照現在 `_remove(a,"old age")`（:1396），不演出。
- **即時**：同樣在那個生態 tick 就 `_remove`（生態、帳本、`archive`、事件都跟離線**完全一樣**，所以生態結果不受即時／離線影響），另外在 `state.departing` 加一個**離場身影**：`{id, species, x, y, heading, ..., target_x, target_y, until}`。
  - 目標：最近的 `exits`（畫面邊緣）或最近的 `fade_spots`（裝飾後面），用 `_hash01(id, …)` 決定，不抽 RNG。
  - 身影用同一套 `_swim` 慢慢游過去（速度 0.6×巡游），繞障礙物；到了或超過 `until`（上限約 120 秒）就從 `departing` 移除。前端在牠到達前後淡出。
  - 身影沒有質量、不吃、不算數量、不影響任何魚（別的魚不閃它）。
  - `death` 事件帶 `leaving:true`；身影的 `id` 就是死者 id。
  - `departing` 存進存檔並驗證（chunk 續跑要逐位元相同）；載入時保留。
- 這樣「個體同一份 snapshot 就不在 `animals`、已在 `archive`」的舊保證（BACKEND_SNAPSHOT_EVENTS.md 事件表 `death` 列）仍成立。

### 4.5 不變式（寫進測試）

- 不餵食時，**場景和裝飾不影響生態**：同 seed、不同場景／裝飾組合，180 天離線（以及 2 天即時）的 `totals`、`causes`、`history`、`resources` 完全相同。這也是 §6.3 可以縮小雲端矩陣的根據。要做到這點，`rng`（生態用）的抽取次數不能依場景而變；位置相關的隨機只能用 `motion_rng` 或 `_hash01`。
- 互動（敲玻璃、游標、切場景、換裝飾）不動 `rng`、不動能量／繁殖／池子。

---

## 5. 切場景、全新世界、FPS

### 5.1 切換場景時魚怎麼搬

- API：`world.set_scene(id: String) -> bool`（未知 id 回 false、不改任何東西）；`world.set_decor(slot: String, style: String) -> bool`（款式不在該槽清單、或把必備槽清空 → false）。
- 狀態：`state.scene`（String）、`state.decor`（`{scene_id: {slot_id: style 或 ""}}`，**每個場景各記一份**，切回來時還是原本的佈置）。
- 搬法（一次完成，前端在全黑的那一刻呼叫）：
  - clownfish → 新場景海葵內的點（依 id 分散）；`Nestling`。
  - seahorse → 新場景的空勾點（依 id 順序分配，必備水草優先）；`Hitched`。
  - royal_gramma → 新場景的空洞，沒有就 `rock_spots`；`Hovering`。
  - chromis → 保持相對位置（x 不變、y 夾進新水層），推出障礙物外；整群一起。
  - `departing` 身影直接清掉（切場景就不演了）。
  - 每隻都設 `relocated_at=elapsed`（前端據此不畫拖尾、直接跳位）；`vx/vy/speed/turn` 歸 0。
  - 不抽 `rng`，也不抽 `motion_rng`（用 id 決定），所以切換不影響之後的隨機序列以外的東西（測試會比較）。
- 換裝飾時：受影響的魚（家被換掉）改家、自己游過去；新放下的障礙物蓋住某條魚時，那條魚被推到外緣（標 `relocated_at`，這是真的瞬間位移）。

### 5.2 全新世界

- `VERSION=3`；`validate` 只收 3。拿掉 v1 升級、legacy 物種、`REEF_CAST/reef_cast/eel_colony`、legacy 欄位（`next_molt/molting_until/shelter/brood_until/tint`）、`totals.molt/predation`。`recent`（每隻最近 6 筆事件）原本給點魚資訊面板用；拿掉點魚後沒人讀，**建議一併拿掉**以縮小存檔（Q7）。
- `StreamStore`：格式字串改 `"stillwater-reef-3"`；`DEFAULT_PATH` 改新檔名（建議 `user://reef.world`，Q4）。舊的 `user://stream.world` **不讀、不改、不刪**（`test_lifecycle` 驗 hash 不變）。舊的 `Stillwater Stream` 資料夾本來就不碰。
- `tests/fixtures/*.var`（v1、v2 各期的舊存檔）刪掉，改成一個檢查：把一個 v2 存檔放在舊路徑，`load_or_create` 開出新世界、舊檔位元組不變。

### 5.3 FPS 60／30／不畫

- 新檔 `scripts/frame_pacer.gd`（Claude 寫，`class_name FramePacer`，純邏輯可測）：
  - `static func mode(can_draw: bool, minimized: bool, focused: bool) -> int`：看不到（最小化或 `window_can_draw()==false`）→ `0`；看得到但不是前景 → `30`；前景 → `60`。
  - `static func apply(mode: int)`：`60/30` → `Engine.max_fps=mode`、`RenderingServer.render_loop_enabled=true`；`0` → 維持現有做法（`max_fps=10` 只為了讓 AppKit 事件還能處理、`render_loop_enabled=false`，`main.gd:507–508`）。
  - 模擬不受影響：`advance_live` 用實際 `delta` 累積、固定 0.2 秒 tick（:278–290），60 FPS 只是每 tick 之間多畫幾張。
- `main.gd` 要 Codex 加的呼叫、改的常數見 §9 H6。
- 耗電／CPU 實測（S16）：打包後在使用者 Mac 上，三種狀態各量 30 分鐘 CPU%，用現有 `tools/foreground_acceptance.py` 的流程；量完才定新的 CPU 上限（定案說「等實測後再定」）。

---

## 6. 驗證計畫

### 6.1 通用綠燈判準（每片都用）

一個測試「過」＝同時滿足（照 `ecology-batch.yml` :95–99 的判法）：
1. `godot --headless --path stream --script tests/<t>.gd` 結束碼 0；
2. 最後一行 JSON 的 `"failures"` 是 `[]` 或 `0`；
3. 輸出裡沒有 `SCRIPT ERROR`、`Parse Error`、`Failed loading resource`。

下文寫「`<t>` 綠」就是指這三項。

### 6.2 測試要改寫／新增

| 測試 | 動作 | 內容 |
|---|---|---|
| `tests/test_scene_data.gd` | **新增**（S1） | §2.6 全部。 |
| `tests/seed_lists.gd` | **新增**（S0） | 固定寬 seed 清單常數（§6.3）。 |
| `tests/test_world.gd` | **重寫**（S3、S4 起，逐片加） | 存檔/還原/重複性/帳本（沿用）；新格式只收 v3、舊檔不讀；新陣容釘死（取代 :65）；不餓死（取代 :164）；不死光（最後一隻、救援必到）；上限＝家的容量限制；繁殖出生在家附近；飼料、敲玻璃、游標各物種反應；`set_scene/set_decor` 合法性；衍生閘門數字釘死（取代 :258）。 |
| `tests/test_natural_motion.gd` | **改寫**（S4、S5–S9） | 保留 chromis 的運動檢查；新增：障礙物（中心 0 次入侵、重疊 ≤0.2、繞行不抖）、clownfish 在海葵範圍內的比例、seahorse 勾住時 `vx=vy=0` 且在勾點、漂流速度上限、gramma 與洞口距離、`extend/nestle/lean` 範圍與限速、離場身影到達目標。多 seed 的檢查預設用 8 個 seed（`seeds()` 仍可用 `--seeds=` 覆寫）。 |
| `tests/test_roaming.gd` | **改寫**（S4） | chromis 活動範圍照舊；新魚改成「活動範圍不超出家附近」的檢查。 |
| `tests/test_presentation.gd` | **加**（S10、S11） | `departing` 與 `death.leaving`；切場景後 `relocated_at`；snapshot 唯讀不動 RNG。 |
| `tests/test_lifecycle.gd` | **改**（S3） | 新舊檔名的 hash 都不變。 |
| `tests/test_long_run_chunks.gd` | **加**（S14） | 帶 `--scene/--decor` 的分段續跑逐位元相同；參數不一致要報錯。 |
| `tests/test_frame_pacer.gd` | **新增**（S13） | `mode()` 真值表；`apply()` 之後 `Engine.max_fps` 與 `render_loop_enabled` 正確。 |
| `tests/long_run.gd` | **改**（S4、S14） | `audit_space`；`--scene`、`--decor=min|max|<json>`；`floor_hits` 與 `presence==100%` 閘門。 |
| `tests/ecology_acceptance.gd` | **不改**（自動跟常數走） | 只有在「保證」改變閘門定義時才動（例如 presence），且在看結果前改。 |

### 6.3 多 seed 掃描（固定寬 seed 清單）

- 背景：之前發現某些閘門只在 42/812/240921 三個 seed 上剛好過（使用者轉述；docs 裡沒有記錄）。新規則：**生態數字要在固定的寬清單上「每一個」都過**，不是多數過。
- 清單（S0 寫進 `tests/seed_lists.gd`，之後不改；要加只能加在後面）：
  `WIDE = [42, 812, 240921, 1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 101, 202, 303, 404, 505, 606, 707, 808, 909, 1234, 4321, 9999, 31337, 65537, 123456, 999983]`（32 個）。
  `MOTION = WIDE.slice(0, 8)`（運動測試用，較慢）。
- 成本：離線 60 天約 3 秒（2026-09-28 實測，seed 42），180 天約 9 秒；32 個 seed × 180 天 ≈ 5 分鐘，本機就能跑；CI 另開一個離線 job 每次都跑。
- 過不了某個 seed 時：改設計數字（上限、來源、繁殖率）重探，**不改閘門、不挑 seed**。

### 6.4 雲端 180 天矩陣

- 分成兩種：
  1. **生態（便宜、寬）**：離線、不餵，`WIDE` 32 個 seed × 180 天，外加 1 個 365 天。因為 §4.5 的不變式（不餵時場景／裝飾不影響生態），這一組不用乘場景與裝飾。
  2. **即時（貴、窄）**：`mode=live`、180 天 × **2 場景 × 2 裝飾組合 × 有餵／不餵 × 3 seed（42、812、240921）＝ 24 條**。
     - 裝飾組合 `min`：只有必備槽、其他全空；`max`：每個槽都放障礙物最大的那款。這兩個是繞行最容易出問題的極端（Q3）。
     - 其他組合：本機（或 core job）用「每款裝飾至少出現在一個組合」的覆蓋清單，各跑即時 1 天，檢查 `audit_space` 0 違規。
- 時間預算：上次每段 60 天 1h23m–2h38m（validation.md:518），上限 5h50m。新版多了障礙物計算，**S14 先用 `tools/motion_tick_bench.gd` 量每 tick 成本**：
  - 若預估每段 60 天 ≤ 4 小時：維持 3 段。
  - 若 > 4 小時：workflow 改成 6 段 × 30 天（`chunk4–6`）。
- 同時 job 數：免費帳號約 20 個同時跑；24 條 × 每階段 → 分兩批觸發（例如先 `feed=none` 的 12 條，再 `feed=daily` 的 12 條），每批約 3 段 × ~2.5h ≈ 7.5 小時。
- 判定：每條跑完 `chunk3` 用同一套 `judge()`；結果照以前格式寫進 `docs/validation.md`（每條一列），沒跑的標「未驗證」。

---

## 7. 分片順序

每片：先寫第一個失敗測試（確認它**因為對的原因**失敗）→ 實作 → 相關測試綠 → 真實 runtime 煙霧測試（開 `-- --qa` 幾秒，或 headless 跑幾秒即時）→ 一個 commit。每片都只 `git add` 自己改的路徑。

**S0 寬 seed 清單與探測工具修正**　〔進度：2026-09-28 完成，`tests/test_probe_tool.gd` 綠〕
- 目標：之後的探測與測試有固定的 seed 清單；探測工具能替換 `RESCUE_AT`、`STREAM_IN`、`OPENING_AGE`。
- 檔案：`tests/seed_lists.gd`（新）、`tools/cast_probe.gd`。
- 先寫的失敗測試：一個小的工具自測（放 `tests/test_probe_tool.gd`）：用 `rescue_at=0` 的設定跑 1 天，patched 原始碼裡必須找得到 `RESCUE_AT: int = 0`（現在會失敗：替換規則找的是 `<=2`，`cast_probe.gd:34`）。
- 完成：`test_probe_tool` 綠；`godot --headless --path stream --script tools/cast_probe.gd -- --config=<json> --seed=42 --days=5` 印出一行 JSON。
- Codex：無。

**S1 場景資料格式、載入器、佔位資料**　〔進度：2026-09-28 完成，`tests/test_scene_data.gd` 綠；macOS 匯出確認 `data/*.json` 在 pck 內，`export_presets.cfg` 不用改。API 名稱與草案不同處：`ReefScene.open(id)`（不叫 `load`，避免蓋掉內建函式）、`bounds` 用 `swim_x/roam_x/feed_x/surface_y`〕
- 目標：§2 全部；世界還不讀它（行為零改變）。
- 檔案：`data/decor.json`、`data/scenes/reef.json`、`data/scenes/shipwreck.json`、`scripts/reef_scene.gd`、`tools/scene_overlay.gd`、`tests/test_scene_data.gd`。
- 先寫的失敗測試：`test_scene_data.gd` 的「reef 場景能載入且 `floor_y(x)` 在 0–1280 每 10 px 與現行 `StreamWorld.floor_y` 差 < 1 px」。
- 完成：`test_scene_data` 綠；`test_world` 綠（證明沒動到世界）；`tools/scene_overlay.gd` 輸出兩張對照 PNG 到 `artifacts/scene-overlay/`；**匯出一次 macOS 包**確認 `data/*.json` 在 pck 裡（例如用 `--export-pack` 後列出內容）。
- Codex：**H1**——請 Codex 看 overlay、確認格式與座標系，之後由 Codex 填正式座標。

**S2 新陣容生態探測（只量不改世界）**　〔進度：2026-09-28 完成。判準 `68b9fc6` 先 commit；結果在 `docs/ecology.md`「Reef v3 cast sizing」：`STREAM_IN.microfauna`=1.2、上限 8/3/4/3=18、開場 6/2/2/2、繁殖照原設計；32 seed × 180 天與 365 天全過（最差 seed 13，microfauna 最低 10.89）。1.35 在 seed 23 不過 C3，沒有更高的備援。工具：`tools/probes/s2_sweep.py`、`tools/probes/2026-09-28-s2-chosen.json`〕
- 目標：定出 `STREAM_IN.microfauna`、三種新魚的 `SPECIES` 數值、`CAP`、開場、`OPENING_AGE`；判準先寫。
- 檔案：`tools/probes/2026-09-28-*.json`（探測設定）、`docs/ecology.md`（新章節：判準、表格、選擇理由）。
- 先寫的「失敗測試」：判準章節先 commit（不含結果），之後才跑探測；表格只填跑出來的數字。
- 完成：粗篩＋細篩（32 seed × 180 天）＋選定設定 365 天的表格都在 ecology.md；選定設定在 32 個 seed 上 `floor_hits`＝0（用「保證已開」的探測版本量，見 S4 的機制；若 S4 還沒落地，先量「原本會餓死的次數」＝0）。
- Codex：無（但數字決定後告知 Codex 上限與開場數，影響畫面擺位）。

**S3 存檔 v3、全新世界（舊陣容暫時保留）**　〔進度：2026-09-28 完成，`8965125`。新存檔 `user://reef.world`、格式 `stillwater-reef-3`、world version 3；只收 v3；舊格式檔不解開、不改、不刪、不另建 recovery。`main.gd` 不必改即正確（`:107` 會把回傳路徑寫回偏好）；可選：`:92` persist-qa 檔名改用 `StreamStore.DEFAULT_PATH.get_file()`、`legacy` 時顯示一句說明。`recent` 暫留，`main.gd:399` 還在讀。〕
- 目標：§5.2；拿掉所有 legacy 升級路徑與欄位。陣容還是現在的四種（讓前端不受影響）。
- 檔案：`scripts/stream_world.gd`（`VERSION`、`restore`、`_upgrade_v1`、`validate`、`spawn` 的 legacy 欄位、`REEF_CAST`、legacy `SPECIES`）、`scripts/stream_store.gd`、`scripts/absence.gd`（文字）、`tests/test_world.gd`（刪 legacy 段落、加新檢查）、`tests/test_lifecycle.gd`、刪 `tests/fixtures/*.var`。
- 先寫的失敗測試：`test_world`：「v2 存檔被 `validate` 拒絕」「`load_or_create(新路徑)` 在舊路徑有 v2 檔時開新世界，舊檔位元組不變」。
- 完成：`test_world`、`test_presentation`、`test_lifecycle`、`test_persist_qa`、`test_long_run_chunks`、`test_natural_motion`、`test_roaming` 綠；`godot --path stream -- --qa` 開 10 秒無錯誤。
- Codex：**H2**——告知存檔改名、舊世界不見是設計如此。**注意**：`main.gd:92` 從 `preferences.cfg` 讀 `world/path`，`:107` 又把路徑寫回去，所以舊使用者的設定裡存的是 `user://stream.world`；只改 `DEFAULT_PATH` 沒用——舊 v2 檔讀不進來時，`load_or_create`（`stream_store.gd:63–69`）會把新世界存到 `stream-recovery-<時間>.world`，而且**每次開啟都再開一個新的**。所以 `main.gd` 要改用新的設定鍵（例如 `world/path_v3`）或忽略舊鍵；這要 Codex 改（或 Codex 同意由 Claude 改這兩行）。S3 的測試要模擬「設定檔裡存著舊路徑」這種情況。

**S4 換陣容（cutover）：新四種＋生態保證＋場景感知地形**　〔進度：2026-09-29 完成於分支 `s4-cast-swap`（前端 `test_frontend` 的「Cruising fish render」兩條要 Codex 改，見下）。後端測試全綠；`tools/cast_probe.gd` 32 個 WIDE seed 180 天與 365 天都 32/32 過 C1–C6（最差 seed 13，microfauna 最低 10.89，沒改任何設計數字，見 ecology.md「S4 re-run」）；`long_run.gd --mode=offline --days=180 --year=false` 32 seed 分 4 批都 `ACCEPTANCE PASS`；`--mode=live --days=1 --seeds=42` 的 `audit_space` 0 違規。`BODY` 用 Codex H3 交接值。另外：夜裡 chromis 只短程游（不橫越）；魚的身體不會低於床面（場景水層下緣比床面低的地方）〕
- 目標：`ACTIVE_SPECIES`＝新四種；S2 定的數字；§4.3 兩個保證；床面／水層／出入口從 `ReefScene`（預設 `reef`）讀；刪 tang/blenny/firefish 全部程式；新魚先用**最簡單的行為**（在家附近的水層裡慢慢游，用 `_swim`），完整行為在 S6–S8。
- 檔案：`scripts/stream_world.gd`、`tests/test_world.gd`、`tests/test_natural_motion.gd`、`tests/test_roaming.gd`、`tests/long_run.gd`（`audit_space` 初版）、`docs/BACKEND_SNAPSHOT_EVENTS.md`（陣容與欄位章節改寫，舊魚段落移到「已移除」）。
- 先寫的失敗測試：`test_world`：「新世界的 `counts()` 等於新開場陣容」「池子全歸零 30 天沒有 `starvation`」「某物種剩 1 隻且過了壽命時不會老死、救援在 24 小時內到」；`test_world`：衍生閘門數字（由 S2 的常數算出後釘死）。
- 完成：上列後端測試全綠；`long_run.gd --mode=offline --days=180 --seeds=<WIDE 全部> --year=false` 印 `ACCEPTANCE PASS`；`--mode=live --days=1 --seeds=42` 的 `audit_space` 0 違規。
- Codex：**H3（最重要的交接）**——這片一落地，後端就不再送 tang/firefish/blenny。落地前要 Codex 先讓 stage 在「看到不認得的物種」時不當掉（畫佔位或不畫），並同意前端測試在那之後由 Codex 更新；`core` job 裡的 `test_frontend`、`test_reef_animation` 可能暫時紅，要事先講好（Q5 附帶）。

**S5 裝飾障礙物與繞行、`set_decor`**　〔進度：2026-09-29/30 完成於分支 `s4-cast-swap`（疊在 S4 上）。`state.decor`（每場景一份）、`set_decor()`、`ReefScene.allows/valid_decor/obstacles/preset`。做法與草案不同：單一橢圓切線繞行會卡在重疊橢圓的縫裡（沉船場景），改成「直線可見就直走，否則走 10 px 格子 A* 路線、朝路線上看得到的最遠點游」；軟門檻的加寬用 0.8×半身。使用者 2026-09-29 的要求取代 §5.1 的「被新障礙蓋住就推到外緣」：改為自己平順游出來、不瞬移。`test_natural_motion` 的障礙檢查（2 場景 × min/max × 8 seed × 23 分鐘）：中心入侵 0、身體重疊最大 0.199、卡住 0、多餘翻身 0、繞行不比開放水域抖。`long_run.gd` 加 `--scene/--decor`（分段續跑暫不支援，S14）與障礙入侵審計。數字見 `ecology.md`「S5」與交接報告〕
- 目標：§3.2；`state.decor`、`set_decor()`；chromis 繞障礙。
- 檔案：`scripts/stream_world.gd`、`tests/test_natural_motion.gd`、`tests/test_world.gd`、`tests/long_run.gd`（`audit_space` 加障礙）。
- 先寫的失敗測試：`test_natural_motion`：「`max` 裝飾組合、8 個 seed、白天 15 分鐘，任何魚的中心在障礙橢圓內的 tick 數＝0」。
- 完成：該測試綠；「身體重疊 ≤0.2」「每 tick 速度變化上限」綠；`set_decor` 合法性檢查綠；即時 1 天 `audit_space` 0 違規。
- Codex：告知 `decor` 欄位格式與 `set_decor()`（**H4**）。

**S5-fix 判準（2026-09-30 先寫後量；取代 S5 看過結果後改的兩個定義）**
獨立反方審查（新 seed 11,13,17,19,23,29,31,37）發現：S5 排除的「讓路窗」有 82% 發生在繞行路線上或障礙旁，障礙全拿掉時只剩 15 對 199，是障礙造成的塞車；另有兩條檢查在新 seed 上紅（障礙重疊 0.205 > 0.2、路線 kinks 0.297 > 0.25），S4 同 seed 全綠。以下判準在修正前寫定，量完不得再改：
- **Seed**：所有障礙相關檢查改用 `seed_lists.gd` WIDE 清單前 16 個（motion() 的 8 個 + 11,13,17,19,23,29,31,37），兩個場景 × 「最少／最多」兩種裝飾。
- **卡住**：任何 30 秒窗內前進 < 15 px 就算「沒進展」，**讓路窗不排除**，除了魚正在自己家（海葵、勾點、洞）1 個 radius 內停留。門檻：障礙相關的沒進展窗（在繞行路線上，或窗內超過一半時間在任一障礙 1.3 倍範圍內）＝ 0；而且任何一條魚都不得連續 2 個窗沒進展。
- **翻身**：同一個導航目標（`nav_tx/nav_ty` 不變）內，翻身次數 ≤ 第一次規劃的路線要求的折返數 + 起步背對時的 1 次；中途重新規劃**不再加額度**。
- **猶豫**：繞行中，同一障礙 1.5 倍範圍內 10 秒內翻身 ≥ 2 次的次數，每個 scene/decor/seed ≤ 同 seed、同位置但障礙全拿掉的對照組次數。
- **原有門檻不動**：身體與障礙重疊 ≤ 0.2、中心入侵 0、`kinks < 0.25`、速度變化上限、`audit_space` 0 違規；在 16 個 seed 上都要過。
- **做法**：修魚的行為（窄縫與沉船附近的互讓與排隊、路線留足身體間距、平順轉向），不改以上任何數字。
- 〔進度 2026-10-04：**暫停，仍紅**（使用者決定）。`583a83d`：RED 測試 `tests/test_obstacles.gd`（`1766b02`）；行為修正 WIP（Claude WIP1–7，Codex 救援：只選連通的開闊水域目的地、整條路線預約窄道、固定讓路順序、沿路線方向閃避）。6 個最難 seed（23,240921,2,29,37,17）× 2 場景 × min/max：卡住窗 0、連續 ≤1、重疊最大 0.132、猶豫 0、kinks 0.160，**只剩 shipwreck/max seed 240921 gramma 多翻身 1 次**；完整 16 seed、其他 backend 測試未跑。每 tick 552 µs（S5 323 µs，同條件前景量，1.71×）。gramma 行為在 S8 重寫，所以先做 S6–S8，做完 S8 再讓本測試在 16 seed 全綠；判準不改。S6–S8 不得讓這 6 seed 面板變差（現況 1 個多翻身）。S4/S5 等本測試全綠才合併 main。〕

**S6 clownfish 行為**
- 目標：§3.1 clownfish 全部 activity、`nestle`、飼料、敲玻璃。
- 檔案：`scripts/stream_world.gd`、`tests/test_natural_motion.gd`、`tests/test_world.gd`、`docs/BACKEND_SNAPSHOT_EVENTS.md`（clownfish 章節）。
- 先寫的失敗測試：「白天 30 分鐘，clownfish 在海葵橢圓內的時間比例 ≥ 0.6、離海葵最遠 ≤ 120 px；敲玻璃後 3 秒內在海葵內」。
- 完成：測試綠；`natural_motion_trace.gd` 產出含 clownfish 的 trace 給 Codex 做動畫。
- Codex：**H5**（新欄位 `nestle`、`home_*`）。

**S7 seahorse 行為**
- 目標：§3.1 seahorse：`Hitched/Drifting`、`lean`、`hitch_x/y`、吸食、換裝飾時換勾點。
- 先寫的失敗測試：「`Hitched` 時 `vx=vy=0` 且身體中心與勾點距離固定；`Drifting` 速度 ≤ 6 px/s；任兩隻不勾同一點；清掉非必備裝飾後 60 秒內所有海馬都 `Hitched` 在剩下的勾點」。
- 其餘同 S6。

**S8 royal_gramma 行為**
- 目標：§3.1 royal_gramma：洞口徘徊、`extend`、無洞時退到 `rock_spots`、換裝飾換家。
- 先寫的失敗測試：「白天，`Hovering` 時離洞口 ≤ 50 px；`min` 裝飾（沒有洞）時家全是 `rock` 且仍 ≥ 上限可用；一洞最多一隻」。
- 其餘同 S6。

**S9 chromis 調整**
- 目標：夜裡在洞口旁休息（有洞時）、繞障礙時魚群不散。
- 先寫的失敗測試：「夜裡、有 `cave_rock` 時，領頭魚休息點離某個 shelter ≤ 60 px」；沿用 `night_rest_checks` 的上下抖動門檻（:427）不能變差。

**S10 老死離場身影**
- 目標：§4.4。
- 檔案：`scripts/stream_world.gd`、`tests/test_presentation.gd`、`tests/test_world.gd`、`tests/test_long_run_chunks.gd`、`docs/BACKEND_SNAPSHOT_EVENTS.md`。
- 先寫的失敗測試：「即時模式下把一隻魚的 `lifespan` 設成現在，下一個生態 tick：牠不在 `animals`、在 `archive`、`death` 事件 `leaving:true`、`departing` 有牠；120 秒內到達 `exits` 或 `fade_spots` 並被移除」「同 seed 即時與離線 180 天的生態 `totals` 相同」。
- Codex：**H7**（`departing[]` 的畫法、淡出時機）。

**S11 切換場景**
- 目標：§5.1；`set_scene()`、每個場景各自的 `decor`。
- 先寫的失敗測試：「`set_scene("shipwreck")` 後：每隻 `relocated_at==elapsed`；clownfish 在新海葵內、seahorse `Hitched` 在新場景勾點、gramma 在新洞或岩點、chromis 在新水層且不在障礙內；`rng` 與 `motion_rng` 狀態不變；切回 `reef` 時 `decor` 是原本那份」。
- Codex：**H8**（淡出淡入時機：全黑時呼叫 `set_scene`）。

**S12 互動收尾**
- 目標：四種魚的餵食、敲玻璃、游標反應全部對上定案；「互動不動 rng、不動生態」檢查補齊。
- 先寫的失敗測試：`test_world` 的 `feeding_checks`（:675）、`startle_checks`（:836）、`lure_checks`（:864）改寫成四種魚版本，先紅。

**S13 FPS 切換 `FramePacer`**
- 目標：§5.3。
- 檔案：`scripts/frame_pacer.gd`、`tests/test_frame_pacer.gd`。
- 先寫的失敗測試：`mode()` 真值表（8 種輸入組合）。
- 完成：`test_frame_pacer` 綠。`main.gd` 的接線由 Codex 做（**H6**），接好後 Claude 用 `-- --qa` 驗：前景時 `Engine.get_frames_per_second()` 接近 60、失焦接近 30、最小化時不畫。

**S14 長跑腳本與 CI 矩陣**
- 目標：`long_run.gd` 支援 `--scene/--decor`；workflow 加 `scene`、`decor` 輸入與一個「寬 seed 離線」job；`core` job 的測試清單更新（加 `test_scene_data`、`test_frame_pacer`；前端測試名單由 Codex 決定）；依 bench 結果決定 3 段或 6 段。
- 檔案：`tests/long_run.gd`、`tests/test_long_run_chunks.gd`、`.github/workflows/ecology-batch.yml`。
- 先寫的失敗測試：`test_long_run_chunks`：「帶 `--scene=shipwreck --decor=max` 的三段續跑＝一次跑完（逐位元）」「續跑時 scene 不一致 → `CHUNK ERROR`」。
- 完成：該測試綠；把 workflow 三段的指令拿到本機用 `mode=offline days=12` 串跑一次，報告與不分段相同（和上次驗證 chunk 流程的方法一樣，validation.md:512）；`tools/motion_tick_bench.gd` 的結果寫進 validation.md。

**S15 雲端 180 天驗證與文件**
- 目標：§6.4 兩組都跑；`BACKEND_SNAPSHOT_EVENTS.md`、`ecology.md`、`validation.md` 全面更新。
- 先寫的「失敗測試」：閘門推導數字已在 S4 釘死；這片只跑、只記錄。
- 完成：24 條 live＋32 seed 離線全部 `ACCEPTANCE PASS`，每條的 run id、每段時間、關鍵數字記進 validation.md；任何一條沒過就停下來找原因（不調門檻）。
- Codex：需要他們的前端測試也在 `core` 綠。

**S16 效能實測與 CPU 上限**
- 目標：打包後在使用者的 Mac 上量 60／30／0 三種狀態的 CPU% 與耗電，定新上限。
- 前提：Codex 的新美術與 FramePacer 接線都已落地；使用者親手測（Cmd-Q、睡眠喚醒）照定案第 4 步。
- 完成：量測數字與方法記進 validation.md；上限寫進 README／PRODUCT。

---

## 8. 風險與未決問題

### 8.1 風險

1. **單一食物池**：四種魚都吃 `microfauna`，預探測已看到餓死（§4.2）。對策：S2 先量；保證機制兜底；探測要求 `floor_hits`＝0。
2. **生態與運動沒有真的分開**：若場景會改變 `rng` 抽取次數，§6.4 的縮小矩陣就不成立。對策：§4.5 的不變式測試（S4、S5 起常駐）。
3. **繞行抖動**：tang 的經驗是障礙／讓路的轉向很容易抖（`stream_world.gd:586–616` 一連串修正）。對策：一開始就限制轉向變化率，並用「每 tick 速度變化上限」的測試擋住。
4. **CI 時間**：障礙物讓每 tick 變慢，60 天一段可能超過 5h50m。對策：S14 先 bench，必要時改 6 段。
5. **換陣容時前端測試變紅**（S4）。對策：H3 事先約好順序。
6. **JSON 沒被打包**：對策：S1 就實際匯出檢查。
7. **工作目錄裡 Codex 未 commit 的改動**碰到 `main.gd`、`stream_stage.gd`、`reef_rig.gd` 等；Claude 各片都不碰這些檔，只 `git add` 自己的路徑。
8. **老死時間即時／離線不同步**：用「生態當下就移除、身影只是呈現」避開；S10 有測試。
9. **`cast_probe.gd` 的 `rescue_at` 選項一直沒作用**（`tools/cast_probe.gd:34`）：以前 ecology.md 若有依賴它的探測列，數字可能不是它標示的設定。S0 修好；舊表格是否受影響，S2 時順手查一次並在 ecology.md 註明。
10. **設定檔記住舊存檔路徑**（`main.gd:92/:107`）：改檔名後舊使用者會每次開啟都產生新的 recovery 世界。對策：H2，S3 測試涵蓋。
11. **「只在 3 個 seed 上靠運氣過」**：docs 裡找不到這次發現的記錄（validation.md 只記了三個 seed 的結果）。對策：S0 的寬清單＋規則「每個 seed 都要過」。

### 8.2 要問使用者的問題（每題附建議答案）

| # | 問題 | 建議答案 |
|---|---|---|
| Q1 | 「不會餓死」要做成**機制保證**嗎？（缺食物時魚只會停止繁殖、不會死；統計上另外記「挨餓時間」） | **是**。定案寫「絕不會餓死」；機制保證比數字運氣可靠。探測仍要求平常完全不碰底線。 |
| Q2 | 「不會死光」要做成：**最後一隻不老死、等到同伴才走**＋**救援 24 小時內必到**嗎？ | **是**。這樣任何時候每種魚至少 1 隻。 |
| Q3 | 定案說「各種裝飾組合都跑雲端 180 天」。組合有上千種，建議：雲端跑每個場景的「最少」和「最多」兩種 × 有餵／不餵 × 3 seed＝24 條；其他組合本機各跑 1 天運動檢查；生態用 32 個 seed 離線覆蓋。可以嗎？ | **可以**。不餵時裝飾不影響生態（有測試保證），貴的即時長跑只需要測繞行最難的兩個極端。 |
| Q4 | 新存檔檔名用 `user://reef.world`（舊 `stream.world` 留著不讀不刪）可以嗎？ | **可以**。舊檔不會被誤讀，也不會被覆蓋。 |
| Q5 | 開場陣容 chromis 6、小丑魚 2、海馬 2、皇家范魚 2（＝12），上限總和大約 15–18，由探測決定；小丑魚上限 ≤ 3。可以嗎？另外換陣容那天，畫面上的新魚可能先是佔位圖，直到你核可 Codex 的新魚美術，可以接受嗎？ | **可以**；若不想看到佔位圖，S4 可以等風格板核可後才合併（後端先在分支上做）。 |
| Q6 | 老死的魚最多花 2 分鐘游到邊緣或裝飾後面再淡出；離開 app 期間老死的只記在「離開摘要」，不演出。可以嗎？ | **可以**。 |
| Q7 | 拿掉「點魚看資訊」後，每隻魚的最近事件（`recent`）和名字沒地方顯示了。要從存檔拿掉 `recent` 嗎？名字留著嗎？ | 拿掉 `recent`；名字留著（日誌文字和未來可能的用途都便宜）。 |

---

## 9. 需要 Codex 配合的介面（交接點）

| # | 何時 | 內容 |
|---|---|---|
| H1 | S1 後 | 場景檔格式與座標系（世界 1280×720；1 粗像素＝幾個世界單位？）；確認由 Codex 填 `data/*.json` 的座標、Claude 跑測試；`tools/scene_overlay.gd` 的對照圖。前端改用 `ReefScene` 讀槽位錨點與款式清單。 |
| H2 | S3 | 新存檔檔名與格式；舊世界不見是設計如此。`main.gd:92/:107` 把存檔路徑記在 `preferences.cfg` 的 `world/path`，要改用新鍵，否則會一直讀舊路徑、每次開啟都另存一個 recovery 新世界（見 S3）。 |
| H3 | S4 前 | **換陣容順序**：stage 先能容忍不認得的物種；S4 落地後 Codex 移除 tang/firefish/blenny 前端與測試；`core` job 的前端測試清單由 Codex 更新。`StreamWorld.floor_y`（static）改成場景相關（例如 `world.floor_y(x)`），`main.gd:295`、`stream_events.gd:61` 要改呼叫；`StreamWorld.SPECIES`（`main.gd:392`、`stream_stage.gd:86, :213`）的 key 換新。新魚的 `BODY` 尺寸（成魚圖長×高，世界單位）請 Codex 提供。 |
| H4 | S5 | `state.decor` 格式、`world.set_decor(slot, style) -> bool`（UI 點槽位換款式／清空）；必備槽只能換不能清空（回 false）。 |
| H5 | S6–S8 | 新欄位：clownfish `nestle`、seahorse `hitch_x/hitch_y/lean`、royal_gramma `extend/den_x/den_y/den_side`、共通 `home_*`；activity 名稱表。每片附 `natural_motion_trace` 的 trace 給動畫參考。 |
| H6 | S13 | `main.gd`：`_process` 裡依 `FramePacer.mode(window_can_draw, minimized, window_is_focused)` 呼叫 `FramePacer.apply()`（取代 :62 的 `max_fps=30` 和 `_set_suspended_view` :507/:518 的寫死值）；QA 前景驗收 `qa_drawn_frames>=50400`（:599）要改成依模式（60 FPS 為 100800）；說明文字（:218）的「Quiet mode: 30 FPS」「Click an animal」要改；動畫一律用實際 `delta`（定案已要求）。 |
| H7 | S10 | `snapshot.departing[]`：畫法和一般魚一樣（同一套運動欄位），到 `target` 附近或 `until` 前淡出；`death` 事件 `leaving:true` 時不要另外演「消失」。 |
| H8 | S11 | 切場景：前端淡出到全黑 → 呼叫 `world.set_scene(id)` → 讀新 snapshot（所有魚都有新的 `relocated_at`，直接跳位）→ 淡入。 |
| H9 | 全程 | 拿掉點魚：`stage.pick`、`_select`（`main.gd:288, :317`）是前端的事；後端沒有對應狀態要改。 |

---

## 10. 未完成／不確定（寫計畫當下）

- 新魚的所有數值（成熟、壽命、代謝、繁殖、上限、`STREAM_IN.microfauna`）都**還沒定**；§4.2 的表只是方向。
- 場景座標全是佔位，要等 Codex 的背景與裝飾圖。
- 新版每 tick 成本、雲端每段時間**未量**。
- JSON 能否被打包**未驗證**（S1 驗）。
- 「只在 3 個 seed 上靠運氣過」這件事的原始紀錄沒找到，本計畫只依使用者轉述處理。
