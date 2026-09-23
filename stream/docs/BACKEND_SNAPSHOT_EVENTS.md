# Backend 快照與自然事件（backend 側契約）

更新：2026-09-23。實作在 `scripts/stream_world.gd`，測試 `tests/test_presentation.gd`。
前端契約（Codex）見 `FRONTEND_BACKEND_CONTRACT.md`；本檔只描述 backend 提供什麼。
注意：該契約寫的 `stream_absence.gd` 實際檔名是 `scripts/absence.gd`。

所有欄位都是**可選、有預設**的新增（2026-09-23 加了 `tint`、`brood_until`、`berried`、`brood_lost`）；存檔容器 `stillwater-stream-1`、world schema version 2、生態率都沒變。
沒有這些欄位的舊存檔（含 v1 升級）照樣驗證與載入。

## snapshot

`world.snapshot()` 仍是 `state` 的深複製（純讀取，不動 `rng`/`motion_rng`/state）。前端相關欄位：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `elapsed` | float | 模擬秒數，單調遞增。 |
| `next_event` | int | 下一個事件 id。目前最新事件 id = `next_event-1`。 |
| `events` | Array | 最近 160 個事件（見下），舊到新。 |
| `animals[].vx`, `animals[].vy` | float，可缺 | 每模擬秒像素速度，即移動積分器的速度：`位置(t) ≈ 位置(t-0.2) + v*0.2`。**缺少視為 0**（剛出生/移入、尚未跑過第一個 motion tick，或 0.4.1 前的存檔）。 |
| `animals[].relocated_at` | float，可缺 | 最近一次「瞬間重定位」的模擬時間。缺少＝從未。 |
| `animals[].tint` | float 0–1，可缺 | **只有蝦**。個體固定的顏色深淺（紅色深度／色點密度），純外觀、不影響生態。開場的蝦各不相同；幼蝦 = 母蝦 tint ± 0.08（夾在 0–1）；移入者自己一個值。**缺少視為 0.6**（魚沒有這欄）。舊存檔載入時會補上。 |
| `animals[].brood_until` | float，可缺 | **只有抱卵中的母蝦**有。孵化的模擬秒（同 `elapsed` 時鐘）。孵化或死亡時移除。 |
| `archive[]` | Array | 最近 96 個離開的個體（含 `cause`、`ended`、最後 x/y、species、age）。 |

### 瞬間重定位

每個 0.2 秒 motion tick，若實際位移與 `v*0.2` 差超過 `StreamWorld.RELOCATION`（3 px），就把 `relocated_at` 設成該 tick 的 `elapsed`。
目前唯一會觸發的是：蝦在水中層改為 `Exploring` 時被貼回苔石表面（30 模擬分鐘約 30 次）；魚的層深夾限位差 < 1 px，不會觸發。

前端判斷：`a.get("relocated_at",-1) > 上一份 snapshot 的 elapsed` → 這段是重定位，不畫長尾流、可直接跳位。

離線補算（`advance_offline`）期間個體不移動，位置和 `vx/vy` 保持離開前的值。

## 事件

`state.events`（以及個體的 `recent`，最多 6 筆）每筆：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `seq` | int | **事件 id**。從 1 單調遞增、不重用，存檔/載入後延續（`next_event` 持久化）。舊存檔的事件沒有 `seq`，永不播放。 |
| `kind` | String | 見下表。 |
| `id` | int | **主角（actor）id**（沿用舊欄位名，不是事件 id）。`begin` 為 0。 |
| `target` | int，可選 | 對象 id。 |
| `time` | float | 模擬秒（同 `elapsed`）。 |
| `x`, `y` | float，可選 | 事件當下主角位置（世界座標 1280×720）。 |
| `live` | bool | `true`＝即時 tick 產生，前端可演出；`false`＝離線補算、載入升級或開場，只進日誌/離開摘要。缺少視為 false。 |
| `cause` | String，可選 | 僅 `death`：`"starvation"`、`"old age"`。舊存檔的歷史事件可能還有 `"predation"`。 |
| `until` | float，可選 | `molt`：躲藏結束的模擬秒（= `molting_until*86400`）。`berried`：預定孵化的模擬秒（= 當下的 `brood_until`）。 |
| `brood_lost` | bool，可選 | 僅 `death`：她死時正在抱卵，卵沒有孵出（沒有 birth/dispersal）。 |
| `text` | String | 日誌文字（英文），不要解析它。 |

| kind | actor (`id`) | `target` | 位置 | 何時 |
|---|---|---|---|---|
| `begin` | 0 | — | — | 新世界開場（live=false）。 |
| `molt` | 脫殼的蝦 | — | 蝦 | 開始脫殼；之後 `activity=="Molting"`，游向 `shelter` x 躲藏，到 `until` 為止。 |
| `berried` | 母蝦 | — | 母蝦 | 開始抱卵；同一份 snapshot 她帶 `brood_until`。約 5 模擬日後孵化。 |
| `birth` | 新生幼體 | 親代 | 幼體（親代 ±30 px） | 幼體已在同一份 snapshot 的 `animals`。蝦的 birth 發生在孵化那一刻。 |
| `dispersal` | 親代 | — | 親代 | 棲地滿，幼體直接漂走；**沒有**幼體個體。 |
| `arrival` | 移入者 | — | 移入者（x=130 或 1150） | 個體已在 `animals`。 |
| `death` | 死亡個體 | — | 死亡個體 | 個體**同一份 snapshot**就不在 `animals`、已在 `archive`。 |
| `departure` | 離開個體 | — | 個體 | 目前只在載入舊存檔移除螯蝦時（live=false）。成年個體不會隨機離開。 |

保證：個體被移除時，事件與移除發生在同一個 `_remove` 呼叫裡，所以不會有「先消失、事件晚到」。

### 抱卵與孵化（2026-09-23）

- 成熟母蝦符合既有繁殖條件時，**不再當場生**：她得到 `brood_until = elapsed + 5*86400`，發 `berried` 事件，繁殖冷卻（7 天）從這一刻起算。
- 抱卵期間不會再開始另一窩。她照常吃、動、脫殼。
- 期滿後的第一個生態 tick（每模擬分鐘一次，所以最晚晚 60 秒）孵化：移除 `brood_until`，照原本規則產生 `birth`（或棲地滿時的 `dispersal`），親代 = 她。孵化時才扣繁殖成本，所以她當時的體力決定孵出 1 或 2 隻（可能 0 隻：體力不夠時沒有事件）。
- 離線補算照樣孵化，事件 `live==false`；每窩只孵一次（孵化即移除 `brood_until`）。
- 抱卵中死亡：卵一起消失，不產生任何幼體，`death` 事件帶 `brood_lost: true`，日誌文字多一句 "Her eggs did not hatch."；存進 `archive` 的個體沒有 `brood_until`。
- 魚不抱卵，繁殖行為不變（符合條件就當場 `birth`/`dispersal`）。

### 前端消費方式（建議）

```gdscript
# 第一次 apply_snapshot：不重播歷史
cursor=value.get("next_event",1)-1
# 之後每次：
for e: Dictionary in StreamWorld.events_after(value.events,cursor):
	if e.get("live",false): play(e)
cursor=value.get("next_event",1)-1
# 若 next_event-1 < cursor（換了世界/重新載入）：只重設 cursor，不播放。
```

`StreamWorld.events_after(events, seq)` 是 static、純函式，不需要 world 物件。
events 只保留 160 筆；若 `events_after` 最舊一筆 `seq > cursor+1`，代表中間有略過（一般是離線補算），不需補播。

捕食已於 2026-09-23 依使用者決定移除：backend 不再產生 `feeding`，`death` 也不再帶 `target`。舊存檔裡的 `feeding` 事件與 `cause=="predation"` 的 `death` 仍然合法、可載入；它們沒有 `seq` 或 `live==false` 時不會播放，前端不用為它們做任何演出。

## 活動名稱（`animals[].activity`）

`Resting`、`Grazing`、`Settling`、`Exploring`、`Swimming`、`Retreating`（蝦受驚短衝，非捕食者）、`Molting`（躲藏）、`Surface feeding`（hatchet）、`Displaying`（threadfin）。
`Sheltering` 在 stage 有列出，但目前 backend 不會設定（`exposure()` 已隨捕食移除）。本次沒有新增或改名任何活動。

## 呈現唯讀

`snapshot()`、`events_after()`、`counts()`、`natural_light()`、`sub_light()`、`biofilm_max()`、`animal_scale()` 及讀取 `state.animals/archive/recent`（選取資訊面板）不消耗 RNG、不改 `export_state()` 位元組（`test_presentation.gd` 驗證）。選取、zoom、viewing light 都在前端，backend 沒有對應狀態。
（`main.gd` 的 `_update_biological_clock()` 會把系統時間寫入 `state.light_hour`，那是生物時鐘，不是 viewing light。）
