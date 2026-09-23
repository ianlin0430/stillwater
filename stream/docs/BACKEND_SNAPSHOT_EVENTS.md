# Backend 快照與自然事件（backend 側契約）

更新：2026-09-23。實作在 `scripts/stream_world.gd`，測試 `tests/test_presentation.gd`。
前端契約（Codex）見 `FRONTEND_BACKEND_CONTRACT.md`；本檔只描述 backend 提供什麼。
注意：該契約寫的 `stream_absence.gd` 實際檔名是 `scripts/absence.gd`。

所有欄位都是**可選、有預設**的新增（2026-09-23 加了 `tint`、`brood_until`、`berried`、`brood_lost`，以及花園鰻的 `burrow_x`、`burrow_y`、`extend`、state 的 `eel_colony`）；存檔容器 `stillwater-stream-1`、world schema version 2、生態率都沒變。
沒有這些欄位的舊存檔（含 v1 升級）照樣驗證與載入。

> **2026-09-23 蝦移除（使用者決定：不要蝦子）**：`ACTIVE_SPECIES` 只剩 `threadfin`、`hatchet`、`garden_eel`；backend 不再產生任何蝦、`tint`、`brood_until`、`molt`、`berried`、`brood_lost`，也不再設定 `Grazing`/`Settling`/`Exploring`/`Retreating`/`Molting`。下文標「**舊檔專用**」的欄位與事件只可能出現在舊存檔的 `archive`、`events`、個體 `recent` 裡；`validate()` 仍接受它們。載入含蝦的存檔時，每隻活著的蝦記一次 `departure`（`live:false`），紀錄進 `archive`（保留 id、name、parent、sex、`tint`，抱卵中的 `brood_until` 移除＝卵作廢、不產生幼體）。`counts()` 只回傳現役三種（沒有 `shrimp` 鍵）；舊的 `history` 樣本可能還有 `shrimp` 鍵。

## snapshot

`world.snapshot()` 仍是 `state` 的深複製（純讀取，不動 `rng`/`motion_rng`/state）。前端相關欄位：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `elapsed` | float | 模擬秒數，單調遞增。 |
| `next_event` | int | 下一個事件 id。目前最新事件 id = `next_event-1`。 |
| `events` | Array | 最近 160 個事件（見下），舊到新。 |
| `animals[].vx`, `animals[].vy` | float，可缺 | 每模擬秒像素速度，即移動積分器的速度：`位置(t) ≈ 位置(t-0.2) + v*0.2`。**缺少視為 0**（剛出生/移入、尚未跑過第一個 motion tick，或 0.4.1 前的存檔）。 |
| `animals[].relocated_at` | float，可缺 | 最近一次「瞬間重定位」的模擬時間。缺少＝從未。 |
| `tint` | float 0–1，可缺 | **舊檔專用**（只在 `archive` 裡的蝦）。曾是蝦的純外觀顏色深淺。backend 不再產生，也不再在載入時補上。 |
| `brood_until` | float，可缺 | **舊檔專用**。曾是抱卵中母蝦的孵化時間；載入時隨蝦離開而移除，現役個體不會有。 |
| `animals[].burrow_x`, `animals[].burrow_y` | float | **只有花園鰻**（必有）。固定的沙洞口，`burrow_y = StreamWorld.floor_y(burrow_x)`。一輩子不變；`x==burrow_x`、`y==burrow_y`。 |
| `animals[].extend` | float 0–1 | **只有花園鰻**。backend 給的目標伸出比例：`0`＝完全在沙裡，`1`＝完全站出。只會是 0 或 1，前端自己平滑地往它動。 |
| `eel_colony` | bool | state 頂層。`true`＝這個世界已經有過花園鰻（新世界開場就是 true）。前端不用讀。 |
| `archive[]` | Array | 最近 96 個離開的個體（含 `cause`、`ended`、最後 x/y、species、age）。 |

### 瞬間重定位

每個 0.2 秒 motion tick，若實際位移與 `v*0.2` 差超過 `StreamWorld.RELOCATION`（3 px），就把 `relocated_at` 設成該 tick 的 `elapsed`。
機制是通用的，保留。以前主要是蝦被貼回苔石表面時觸發；蝦移除後，正常遊玩時魚的層深夾限位差 < 1 px，**實際上不會觸發**，只有魚出現在自己的層外（例如手改過的存檔）被夾回時才會標記（`test_presentation` 驗證）。

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
| `until` | float，可選 | **舊檔專用**。`molt`：躲藏結束的模擬秒；`berried`：預定孵化的模擬秒。 |
| `brood_lost` | bool，可選 | **舊檔專用**。僅 `death`：她死時正在抱卵。 |
| `text` | String | 日誌文字（英文），不要解析它。 |

| kind | actor (`id`) | `target` | 位置 | 何時 |
|---|---|---|---|---|
| `begin` | 0 | — | — | 新世界開場（live=false）。 |
| `molt` | 脫殼的蝦 | — | 蝦 | **舊檔專用**，不再產生。 |
| `berried` | 母蝦 | — | 母蝦 | **舊檔專用**，不再產生。 |
| `birth` | 新生幼體 | 親代 | 幼體（親代 ±30 px；花園鰻＝新洞口） | 幼體已在同一份 snapshot 的 `animals`。 |
| `dispersal` | 親代 | — | 親代 | 棲地滿，幼體直接漂走；**沒有**幼體個體。 |
| `arrival` | 移入者 | — | 移入者（x=130 或 1150；花園鰻＝牠的沙洞口） | 個體已在 `animals`。 |
| `death` | 死亡個體 | — | 死亡個體 | 個體**同一份 snapshot**就不在 `animals`、已在 `archive`。 |
| `departure` | 離開個體 | — | 個體 | 只在載入舊存檔移除螯蝦或蝦時（live=false），每隻一次、重開不重複。成年個體不會隨機離開。 |

保證：個體被移除時，事件與移除發生在同一個 `_remove` 呼叫裡，所以不會有「先消失、事件晚到」。

### 抱卵與孵化（已隨蝦移除，舊檔專用）

2026-09-23 曾加入蝦抱卵 5 天再孵化；同日蝦整個移除，這套機制（`_berry`、`BROOD_DAYS`、孵化 tick）已刪。魚與花園鰻符合條件就當場 `birth`/`dispersal`。舊存檔裡抱卵中的母蝦在載入時離開，卵作廢。

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

## 花園鰻（2026-09-23）

斑點花園鰻 *Heteroconger hassi*，`species:"garden_eel"`，`StreamWorld.SPECIES.garden_eel` 有 `label:"Spotted garden eel"`、`latin`。海水魚，使用者明確決定照放在這條溪，不是疏忽。

- **位置**：每隻有固定沙洞 `burrow_x/burrow_y`，從 `StreamWorld.BURROWS`（x = 650、684、616、718、582、752、548、786）挑「離親代的洞最近、還沒被佔的」一格（沒有親代就從 650 附近開始），不用亂數，所以同一個世界每次都一樣。洞口間距 34 px，不會重疊。最多 4 隻時只會用到 616–718 這一小片。
- 花園鰻**永遠不移動**：`x/y` = 洞口，`vx=vy=0`，`direction` 固定（出生時 x<640 為 1，否則 −1；目前的洞都 ≥548，多半是 −1，前端可自己決定朝向）。不會出現 `relocated_at`。
- **行為**（每個 0.2 秒 motion tick 由 backend 決定，不用 `motion_rng`）：
  - 夜裡（`light_hour<7 或 >19`，和其他魚同一個定義）：`activity:"Sleeping"`，`extend:0`。
  - 白天：`"Swaying"`，`extend:1`（站出沙面、吃漂過的小生物）。
  - 白天有魚（threadfin 或 hatchet）在洞口左右 48 px 內、而且在洞口上方 200 px 內（大約是 threadfin 那一層的最底部）：`"Retracted"`，`extend:0`；魚離開後再過 4 秒回到 `"Swaying"`。實測白天約 3–5% 的時間是縮著的，每隻每 20 分鐘縮 2–7 次。常數在 `StreamWorld.EEL_WARY`。
  - 使用者撥水/水紋讓花園鰻縮回，只是前端的呈現，backend **沒有**任何輸入介面，也不該有。
- **出生**：`birth` 事件的 x/y 就是幼魚的新洞口（在親代的洞附近）。棲地滿（4 隻）時是 `dispersal`，沒有幼魚個體。
- **移入**：移入的花園鰻**直接出現在自己的洞口**，`arrival` 事件的 x/y＝洞口。backend 不模擬「從上游游進來」；前端要演「從上游邊緣游進來、鑽進洞」可以純呈現地做（例如從 x=130 或 1150 游到 `burrow_x`），不需要 backend 欄位。
- **舊存檔**：沒有 `eel_colony` 的存檔（2026-09-23 以前的 v2，以及 v1 升級）載入時，會自動來一對（一公一母）成年花園鰻，產生兩筆 `arrival`，`live:false`（不演出，只進日誌/離開摘要），物質記在 `ledger.in`。只發生一次；之後就算花園鰻死光也不會因為載入而補回（要靠一般的移入救援）。
- 吃的是 `microfauna`（和 threadfin、hatchet 同一個池），會餓死、老死（壽命 365 天 ±15%，90 天成熟）。

## 活動名稱（`animals[].activity`）

魚：`Resting`、`Swimming`、`Surface feeding`（hatchet）、`Displaying`（threadfin）。
舊檔專用（蝦，只可能出現在 `archive`）：`Grazing`、`Settling`、`Exploring`、`Retreating`、`Molting`。
花園鰻專用：`Swaying`（白天站出沙面）、`Retracted`（有魚經過，暫時縮回）、`Sleeping`（夜裡在洞裡）。
`Sheltering` 在 stage 有列出，但目前 backend 不會設定（`exposure()` 已隨捕食移除）。

## 呈現唯讀

`snapshot()`、`events_after()`、`counts()`、`natural_light()`、`sub_light()`、`biofilm_max()`、`animal_scale()` 及讀取 `state.animals/archive/recent`（選取資訊面板）不消耗 RNG、不改 `export_state()` 位元組（`test_presentation.gd` 驗證）。選取、zoom、viewing light 都在前端，backend 沒有對應狀態。
（`main.gd` 的 `_update_biological_clock()` 會把系統時間寫入 `state.light_hour`，那是生物時鐘，不是 viewing light。）
