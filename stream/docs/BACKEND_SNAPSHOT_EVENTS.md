# Backend 快照與自然事件（backend 側契約）

更新：2026-09-26 晚（黃金吊啃食改成側面：身體中心離嘴半個身長 `TANG.reach`＝61 px × 體型，岩石點剩 4 個；綠光鰓雀鯛會避開啃食中黃金吊的身體，見「黃金吊」）。2026-09-26（自然游動欄位 heading/pitch/speed/thrust/turn/roll/flick、身體不重疊、blenny 避開紫雷達洞口；見「自然游動欄位」）。2026-09-25（最終四物種：花園鰻移除；紫雷達洞口重新排開；黃金吊岩石點互斥；新增 `ate` 事件）。實作在 `scripts/stream_world.gd`，測試 `tests/test_presentation.gd`、`tests/test_world.gd`（`eel_checks`、`feeding_checks`、`blenny_checks`、`firefish_checks`、`chromis_checks`、`tang_checks`、`reef_cast_checks`）。
前端契約（Codex）見 `FRONTEND_BACKEND_CONTRACT.md`；本檔只描述 backend 提供什麼。
注意：該契約寫的 `stream_absence.gd` 實際檔名是 `scripts/absence.gd`。

所有欄位都是**可選、有預設**的新增（2026-09-23 加了 `tint`、`brood_until`、`berried`、`brood_lost`，以及花園鰻的 `burrow_x`、`burrow_y`、`extend`、state 的 `eel_colony`）；存檔容器 `stillwater-stream-1`、world schema version 2、生態率都沒變。
沒有這些欄位的舊存檔（含 v1 升級）照樣驗證與載入。2026-09-24 再加：紫雷達的 `burrow_x`/`burrow_y`/`extend`/`hover_y`、黃金吊的 `contact_x`/`contact_y`（只在 `Grazing` 時存在）、state 的 `reef_cast`；同樣都是可選、schema 不變。

> **2026-09-25 最終四物種（使用者決定：不要花園鰻，取代下一段的五物種）**：`ACTIVE_SPECIES` = `lawnmower_blenny`、`purple_firefish`、`green_chromis`、`yellow_tang`（這個順序；`counts()` 就是這四個鍵，沒有 `garden_eel`）。
> - **`garden_eel` 變成舊檔專用**（和 threadfin 一樣）：`SPECIES.garden_eel` 還在（`initial:0`），不在 `CAP`、`HOMES`、`REEF_CAST`；backend 不再產生、不會移入、不會救援。載入含活花園鰻的存檔時，每隻記一次 `departure`（`live:false`，x/y＝牠的洞口），進 `archive` 時保留 `burrow_x`/`burrow_y`/`extend`；重開不重複。舊存檔裡鰻的欄位與事件（`Swaying`/`Retracted`、`eel_colony`）照樣驗證、可載入。沒有 `eel_colony` 的舊存檔**不再**補一對鰻。新世界不再寫 `eel_colony`。
> - 棲地上限 blenny 3、紫雷達 4、chromis 8、黃金吊 2（合計 17）；開場 2/2/6/2 = 12（第六隻 chromis 叫 Pearl）。舊溪流存檔的 `reef_cast` 開場成員因此是 2 blenny、2 紫雷達、6 chromis、2 黃金吊。
> - 紫雷達洞口改成 `FIRE_BURROWS` = 650、540、760、410（見「紫雷達」）；黃金吊的岩石點 2/3、4/5 互斥（2026-09-26 起剩 4 個點，只有右礁石 3/4 互斥；見「黃金吊」）；新事件 `ate`（見「事件」）。

> **2026-09-24 五物種（已被上面取代）**：`ACTIVE_SPECIES` = `lawnmower_blenny`、`purple_firefish`、`green_chromis`、`garden_eel`、`yellow_tang`（這個順序；`counts()` 就是這五個鍵）。
> - **紅雷達的鍵 `firefish` 已完全刪除**，換成 `purple_firefish`（label `"Purple firefish"`，latin *Nemateleotris decora*），行為和原本的火焰鰕虎完全一樣。珊瑚礁世界只在今天的開發 commit 存在過，沒有使用者存檔、也沒有測試 fixture 含 `firefish`，所以不留舊檔專用項目；含 `firefish` 的存檔會被 `validate()` 拒絕（實際上不存在）。
> - **新增黃金吊 `yellow_tang`**（label `"Yellow tang"`，*Zebrasoma flavescens*）：池裡最大的魚，和 blenny 一起吃 `biofilm`。欄位與活動見文末「黃金吊」。
> - 棲地上限 blenny 3、紫雷達 3、chromis 6、花園鰻 4、黃金吊 2（合計 18）；開場 2/2/5/2/2 = 13。舊的溪流存檔載入時，`reef_cast` 開場成員是 2 blenny、2 紫雷達、5 chromis、2 黃金吊（`arrival`，`live:false`）。

> **2026-09-24 珊瑚礁陣容（四物種，已被上面取代）**：`ACTIVE_SPECIES` = `lawnmower_blenny`、`firefish`、`green_chromis`、`garden_eel`（這個順序）。**threadfin 移除**，和斧頭魚、蝦一樣成為舊檔專用：載入舊存檔時每隻活著的 threadfin 記一次 `departure`（`live:false`），接著（每個存檔只一次，`reef_cast` 旗標）新陣容的開場成員 2 blenny、2 firefish、5 chromis 以一般 `arrival`（`live:false`，不演出）出現。新世界開場就有 `reef_cast:true`。`counts()` 只有這四個鍵。各物種欄位、活動與互動見文末「珊瑚礁陣容」。**stage 目前只畫 `threadfin`/`hatchet`（`PRESENTED_SPECIES`），所以新陣容在畫面上看不到，但不會當掉**；四個物種都需要 Codex 畫 rig。

> **2026-09-23 蝦移除（使用者決定：不要蝦子）**：`ACTIVE_SPECIES` 只剩 `threadfin`、`garden_eel`（斧頭魚也在同一天依使用者決定移除，舊檔的斧頭魚同樣在載入時記一次 `departure`）；backend 不再產生任何蝦、`tint`、`brood_until`、`molt`、`berried`、`brood_lost`，也不再設定 `Grazing`/`Settling`/`Exploring`/`Retreating`/`Molting`。下文標「**舊檔專用**」的欄位與事件只可能出現在舊存檔的 `archive`、`events`、個體 `recent` 裡；`validate()` 仍接受它們。載入含蝦的存檔時，每隻活著的蝦記一次 `departure`（`live:false`），紀錄進 `archive`（保留 id、name、parent、sex、`tint`，抱卵中的 `brood_until` 移除＝卵作廢、不產生幼體）。`counts()` 只回傳現役物種（沒有 `shrimp`、`hatchet` 鍵）；舊的 `history` 樣本可能還有 `shrimp` 鍵。

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
| `animals[].burrow_x`, `animals[].burrow_y` | float | **紫雷達**（必有；舊檔 `archive` 裡的花園鰻也有）。固定的沙洞口，`burrow_y = StreamWorld.floor_y(burrow_x)`。一輩子不變；`x==burrow_x`、`y==burrow_y`。 |
| `animals[].extend` | float 0–1 | **紫雷達**（舊檔的花園鰻也有）。backend 給的目標：`0`＝在洞裡，`1`＝出洞（懸停在洞口上方 `hover_y`）。只會是 0 或 1，前端自己平滑地往它動。 |
| `animals[].hover_y` | float px | **只有紫雷達**（必有，24–40，每隻固定）。出洞時懸停在洞口上方的高度：畫在 `(burrow_x, burrow_y - extend_平滑後 × hover_y)`。 |
| `animals[].contact_x`, `animals[].contact_y` | float，可缺 | **只有黃金吊，而且只在 `activity=="Grazing"` 時存在**：嘴巴碰到的岩石點（`StreamWorld.TANG.spots` 其中一個）。不在啃食時一定不存在。見文末「黃金吊」。 |
| `reef_cast` | bool | state 頂層。`true`＝珊瑚礁陣容已經到過（新世界開場就是 true）。前端不用讀。 |
| `eel_colony` | bool，可缺 | **舊檔專用**。2026-09-23–25 的存檔有它；新世界不再寫。validate 仍要求是 bool。前端不用讀。 |
| `archive[]` | Array | 最近 96 個離開的個體（含 `cause`、`ended`、最後 x/y、species、age）。 |

### 自然游動欄位（2026-09-26，使用者要求「自然優先」）

全部是**可選、有預設**的 per-animal 欄位（schema version 不變，`validate()` 只要求出現時是有限數字）。實作 `StreamWorld._swim`（chromis、黃金吊）、`_blenny`、`_burrower`；規格測試 `tests/test_natural_motion.gd`；證據 `artifacts/natural-motion/`（gitignored）。backend 只給數字，身體／鰭怎麼動由 Codex 的 rig 決定。**缺欄位時**（舊存檔、剛出生還沒跑第一個 motion tick）：`heading = 0 if direction>0 else π`，其餘當 0。

| 欄位 | 誰有 | 範圍 | 意義 |
|---|---|---|---|
| `heading` | chromis、黃金吊、blenny、紫雷達 | 0…π，**連續**、不會繞圈跳 | 身體偏航角（側視水族箱）：`0`＝朝右、`π`＝朝左、`π/2`＝轉身中正對玻璃。轉身是**限速**的，不會瞬間翻面：chromis 最多 4 rad/s（受驚 16）、黃金吊 1.2 rad/s（受驚 4.8，大轉彎）、blenny 7 rad/s（受驚 14）。rig 建議：左右鏡像用 `sign(cos(heading))`，寬度壓縮用 `abs(cos(heading))`（轉身時變窄＝身體轉向觀眾）。紫雷達固定 0 或 π。 |
| `direction` | 全部 | ±1 | 相容用，**= sign(cos(heading))**（`abs(cos)`≤0.05 時保持前一個值）。舊的讀法照樣可用，但翻面會落在轉身正中間。 |
| `pitch` | chromis、黃金吊、紫雷達（blenny 固定 0） | rad，正＝頭朝下（螢幕 y 向下） | 頭上仰／下俯。chromis 最多 ±0.7、黃金吊 ±0.45，限速（0.8、0.5 rad/s）；紫雷達懸停時是 ±0.065 內的小平衡擺動。 |
| `speed` | chromis、黃金吊、blenny、紫雷達（=0） | px/s ≥0 | 沿身體方向的游速（不含胸鰭微調）。blenny＝這個 tick 的實際位移速度（= `abs(vx)`）。 |
| `thrust` | 全部 | 0…1 | 此刻的推進出力。**chromis**：胸鰭划水的 burst（接近 1）與滑行（0）交替＝「停停走走」；**黃金吊**：平穩划水，巡游約 0.5–0.65，帶一點每 1.6 秒的划水起伏；**blenny**：只有尾巴一甩（flick）那一個 tick 是 >0（最大 1），其餘滑行＝0；**紫雷達**：懸停時 0.12–0.2 的平衡鰭動，**衝回洞那一 tick = 1**，之後每 tick −0.5。出力上升有斜率限制（每秒最多 +2.0），滑行立即開始。 |
| `turn` | chromis、黃金吊、blenny、紫雷達（=0） | rad/s，帶號 | `heading` 的變化率（正＝往朝左轉）。rig 可拿來做頭先轉、尾巴延遲的彎身。 |
| `roll` | 只有黃金吊 | 0…0.35 rad | 啃岩石時每一口（每 1.6 秒）身體往岩面傾斜；不啃時緩緩回到 0。 |
| `flick` | 只有紫雷達 | 0 或 1 | 背鰭長棘偶爾一彈（平均約每 12 秒一次，只在 `Hovering`），該 tick 為 1。前端自己做彈起再慢慢收回。 |
| `avoid_x`, `avoid_y` | chromis、黃金吊 | px/s | 閃避其他身體時加上的轉向（已平滑）。前端不用讀；長度 >0 代表正在讓路（測試用它分辨「閃避」與「一般巡游」）。 |
| `chew_until` | 只有黃金吊（吃過之後） | 模擬秒 | 吃完一粒後 5 秒內不追下一粒，好讓另一隻輪流。前端不用讀。 |

各物種的樣子（backend 端）：
- **綠光鰓雀鯛**：胸鰭划水（labriform）的 burst-and-glide：速度在想要的速度 ±30% 之間一推一滑（巡游時 CV ≈0.29）。成員在自己位置附近時朝向跟領頭魚的 `direction` 一樣，所以整群幾乎同時轉身（領頭魚過了一半，成員跟上）。隊形半徑慢慢 ±12% 呼吸。
- **黃金吊**：平穩划水、長滑行（巡游 CV ≈0.06）、大轉彎（轉身 ≈2.6 秒，轉身時前進速度自然變慢）；啃岩石時 `roll`。到岩石點後**先轉身面對岩石才開始 `Grazing`**，所以 `Grazing` 時 `direction == -side` 且與 `heading` 一致。
- **紫雷達**：`x/y` 仍永遠是洞口、`vx=vy=0`（懸停的小飄動前端照舊自己加）；backend 給平衡用的 `pitch`/`thrust`、偶發 `flick`、以及衝回洞的 `thrust=1`。
- **草食鳚**：停著時完全不動（`speed=0`，眼睛由前端動）；要走時先原地轉向（`turn`），尾巴一甩（`thrust`>0）以剛好能滑到落點的速度出發（最多 45 px/s，受驚 90），滑行減速（每秒 ×0.24），最後不低於 8 px/s 落地；太遠就再甩一次（skitter）。backend 的 y 仍貼床面，跳的弧線前端畫。

路徑與速度（chromis、黃金吊）：不再等速直線、也不會在目標點急停：接近目標時依煞車能力減速（chromis 24、黃金吊 8 px/s²），旅行時有緩和的上下起伏；靠近水層上下緣（40 px 內）或左右牆時，往邊緣的轉向會漸弱，不是硬夾（實測層外 0 次、`relocated_at` 0 次）。位移仍是 `位置(t) ≈ 位置(t-0.2) + v*0.2`；`vx/vy` 是實際速度（身體方向速度＋低速時最多 6 px/s 的胸鰭微調）。全部由時間與 id 決定，沒有每 tick 的亂數；motion tick 仍是 0.2 秒。

身體不重疊（2026-09-26）：兩隻黃金吊、以及 chromis 與黃金吊之間，用兩者成魚圖（`StreamWorld.BODY`，同 `ReefRig.LOOK`；幼體減半）的合併半身橢圓保持距離，預測 5 秒內的相遇、主要往上下閃；chromis 讓黃金吊，兩隻黃金吊之間「啃食中的優先、剛吃過的讓、否則 id 大的讓」。餵食時黃金吊會預判下沉中的飼料位置，並略過另一隻正在吃的黃金吊身體範圍內的飼料。草食鳚不會在任何有紫雷達住的洞口 104 px（`BLENNY.burrow_clear`）內停、啃或睡（發現自己在範圍內就跳開）；黃金吊的啃食點都不會讓身體蓋到床面上的 blenny（測試檢查）。

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
| `food_id` | int，可選 | 僅 `ate`：被吃掉的飼料 id（`state.food[].id`；那一粒在同一份 snapshot 已經不在 `food` 裡）。 |
| `food_x`, `food_y` | float，可選 | 僅 `ate`：那一粒被吃掉時的位置。 |
| `text` | String | 日誌文字（英文），不要解析它。`ate` 的 text 是空字串。 |

| kind | actor (`id`) | `target` | 位置 | 何時 |
|---|---|---|---|---|
| `begin` | 0 | — | — | 新世界開場（live=false）。 |
| `molt` | 脫殼的蝦 | — | 蝦 | **舊檔專用**，不再產生。 |
| `berried` | 母蝦 | — | 母蝦 | **舊檔專用**，不再產生。 |
| `birth` | 新生幼體 | 親代 | 幼體（親代 ±30 px，blenny 在沙床上，chromis/黃金吊在自己的水層；紫雷達＝離親代最近的空洞口） | 幼體已在同一份 snapshot 的 `animals`。 |
| `dispersal` | 親代 | — | 親代 | 棲地滿，幼體直接漂走；**沒有**幼體個體。 |
| `arrival` | 移入者 | — | 移入者（x=130 或 1150，blenny 在那裡的沙床上、chromis/黃金吊在自己的水層；紫雷達＝牠的沙洞口） | 個體已在 `animals`。載入舊存檔時的珊瑚礁開場成員也是 `arrival`，`live:false`。 |
| `death` | 死亡個體 | — | 死亡個體 | 個體**同一份 snapshot**就不在 `animals`、已在 `archive`。 |
| `departure` | 離開個體 | — | 個體（花園鰻＝牠的洞口） | 只在載入舊存檔移除已下架物種（螯蝦、蝦、斧頭魚、threadfin、花園鰻）時（live=false），每隻一次、重開不重複。成年個體不會隨機離開。 |
| `ate` | 吃的動物 | — | 動物（紫雷達＝洞口；飼料位置在 `food_x/food_y`） | 即時遊玩中一粒飼料被吃掉的那個 0.2 秒 tick，**一定是 `live:true`**；帶 `food_id`。離線、沉底分解（900 秒）都**不會**產生。見下「`ate`」。 |

保證：個體被移除時，事件與移除發生在同一個 `_remove` 呼叫裡，所以不會有「先消失、事件晚到」。

### `ate`：誰吃了哪一粒（2026-09-25，Codex 要求）

- 每吃掉一粒就一筆（一撮 5 粒最多 5 筆，一天最多 20 筆）。`id`＝吃的動物，`food_id`＝那一粒，`x/y`＝動物當下位置（chromis、黃金吊、blenny 離那一粒都在 `FOOD.eat`＝12 px 內；紫雷達的 `x/y` 是洞口，那一粒在洞口左右 22 px、上方 80 px 內），`food_x/food_y`＝那一粒的位置。飼料消失、能量增加和事件在同一個 tick、同一份 snapshot。
- 前端用法：`e.kind=="ate" and e.live` → 讓 `rigs[e.id]` 做一次咬的動作、在 `(food_x, food_y)` 收掉那一粒。沒有 `ate` 而消失的飼料＝沉底後分解（`detritus`），不要演成被咬。
- **不吵**：text 是空字串（日誌/面板不要顯示它）；不進動物的 `recent`（選取面板的故事不會被咬的紀錄洗掉）；不計入 `totals`（離開摘要不受影響）；`state.events` 裡只保留最新的 `FOOD.max_bites`＝10 筆 `ate`，更舊的 `ate` 會被拿掉（別的事件不受影響）。因為只保留 10 筆，前端要在每次 snapshot 用 `events_after(cursor)` 取新的，不要回頭找舊的咬。
- 不影響生態：它只記錄已經發生的進食；不抽亂數。

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

## 花園鰻（2026-09-23；2026-09-25 移除，以下只描述舊存檔裡可能看到的樣子）

**2026-09-25 起 backend 不再有活的花園鰻**：`BURROWS`、`EEL_WARY` 常數與鰻的行為程式已刪（紫雷達的躲避規則搬到 `FIRE.dx`/`FIRE.dy`，數值不變）。舊存檔載入時活的鰻各記一次 `departure`。下文保留當時的行為說明，供讀舊存檔的 `archive`/`events` 參考。

斑點花園鰻 *Heteroconger hassi*，`species:"garden_eel"`，`StreamWorld.SPECIES.garden_eel` 有 `label:"Spotted garden eel"`、`latin`。

- **位置**：每隻有固定沙洞 `burrow_x/burrow_y`，從當時的 `BURROWS`（x = 650、684、616、718、582、752、548、786）挑「離親代的洞最近、還沒被佔的」一格（沒有親代就從 650 附近開始），不用亂數，所以同一個世界每次都一樣。洞口間距 34 px，不會重疊。最多 4 隻時只會用到 616–718 這一小片。
- 花園鰻**永遠不移動**：`x/y` = 洞口，`vx=vy=0`，`direction` 固定（出生時 x<640 為 1，否則 −1；目前的洞都 ≥548，多半是 −1，前端可自己決定朝向）。不會出現 `relocated_at`。
- **行為**（每個 0.2 秒 motion tick 由 backend 決定，不用 `motion_rng`）：
  - 夜裡（`light_hour<7 或 >19`，和其他魚同一個定義）：`activity:"Sleeping"`，`extend:0`。
  - 白天：`"Swaying"`，`extend:1`（站出沙面、吃漂過的小生物）。
  - 白天有魚（2026-09-24 起是 green_chromis；原本是 threadfin）在洞口左右 48 px 內、而且在洞口上方 200 px 內（大約是 chromis 那一層的最底部）：`"Retracted"`，`extend:0`；魚離開後再過 4 秒回到 `"Swaying"`。實測白天約 3–5% 的時間是縮著的，每隻每 20 分鐘縮 2–7 次。常數在 `StreamWorld.EEL_WARY`。
  - 使用者撥水/水紋讓花園鰻縮回，只是前端的呈現，backend **沒有**任何輸入介面，也不該有。
- **出生**：`birth` 事件的 x/y 就是幼魚的新洞口（在親代的洞附近）。棲地滿（4 隻）時是 `dispersal`，沒有幼魚個體。
- **移入**：移入的花園鰻**直接出現在自己的洞口**，`arrival` 事件的 x/y＝洞口。backend 不模擬「從上游游進來」；前端要演「從上游邊緣游進來、鑽進洞」可以純呈現地做（例如從 x=130 或 1150 游到 `burrow_x`），不需要 backend 欄位。
- **舊存檔**（**2026-09-25 起不再這樣做**：不補鰻，`eel_colony` 只驗證型別）：當時，沒有 `eel_colony` 的存檔（2026-09-23 以前的 v2，以及 v1 升級）載入時，會自動來一對（一公一母）成年花園鰻，產生兩筆 `arrival`，`live:false`（不演出，只進日誌/離開摘要），物質記在 `ledger.in`。只發生一次；之後就算花園鰻死光也不會因為載入而補回（要靠一般的移入救援）。
- 吃的是 `microfauna`（和 firefish、chromis 同一個池），會餓死、老死（壽命 365 天 ±15%，90 天成熟）。

## 餵食、敲玻璃、游標引魚（2026-09-23，使用者決定）

三個都是 **world 的公開 API，只由 `main.gd` 呼叫**；stage 仍然只讀 snapshot。都只在即時遊玩時發生。

### 餵食：真的食物，但不是必要
- `feed(x) -> bool`：在水面（y=`FOOD.surface`=56）x 處撒一撮，5 粒、每粒 `mass` 0.05。超過每日上限（`FOOD.daily`=1.0，也就是一天 4 撮）或水裡已有 40 粒時回 `false`，前端顯示「吃飽了」。
- 飼料以每秒 10 px 下沉，碰到沙床就 `settled`，900 秒後變成 `detritus`。
- 魚在 260 px 內、自己水層可及、而且還吃得下時會游過去（`activity:"Feeding"`，`food_id` 指向那一粒），吃到的 80% 變成能量、20% 進 `detritus`。懸停中的紫雷達會叼走洞口左右 22 px、上方 80 px 內漂過的飼料。每吃掉一粒都有一筆 `ate` 事件（見「事件」）。
- 物質：飼料記在 `ledger.in`，之後流向動物或碎屑，residual ≈ 0。
- **不餵完全沒影響**：沒有飼料時不消耗 RNG、不產生新欄位；固定種子下，改動前後的狀態 digest 與兩組 RNG 都相同（seed 42/812/240921，含即時、離線與 72 小時補算）。
- 離線補算不模擬追食，只讓已經撒下的飼料照常沉降、分解。
- snapshot：`food: [{id, x, y, mass, settled, settled_at}]`（沒有就不存在，視為空陣列）、`fed: {day, mass}`（今天已撒的量）。事件 `fed`（`live:true`，x/y＝撒下的位置，沒有 actor）。

### 敲玻璃
- `startle(x, y, strength=1.0) -> int`（回傳注意到的動物數）：260 px 內的魚往反方向衝最多 150 px、維持在自己水層內，`activity:"Startled"` 3 秒；範圍內的紫雷達鑽回洞 5 秒。
- 不影響能量、繁殖或任何生態數值；不存檔。

### 游標引魚
- `set_lure(point)` / `clear_lure()`：游標在水裡停住時，45 秒內、320 px 內的魚在下一次選擇動作時有一半機率過來看，停在游標旁 36 px、自己的水層內，`activity:"Curious"` 6–12 秒。游標移動不到 8 px 不算換位置。
- lure 不是 `state` 的一部分，不存檔；只有 lure 存在時才會從 `motion_rng` 抽亂數。

### main.gd 的暫時接線（等 Codex 做正式 UI）
- F：在游標位置撒飼料（沒有游標就在畫面中央）；被拒絕時狀態列顯示 “They’re full for today — natural food keeps them going.”
- T，或點畫面上水域以外的邊框：敲玻璃。
- 游標在水裡停 1.5 秒：設 lure；移開或暫停、隱藏時清掉。

## 活動名稱（`animals[].activity`）

綠光鰓雀鯛（green_chromis）：`Schooling`、`Resting`，以及互動造成的 `Feeding`、`Startled`、`Curious`（只有領頭魚）。
草食鳚（lawnmower_blenny）：`Grazing`、`Perching`、`Hopping`、`Sleeping`（夜裡），以及 `Feeding`（去啄沉底飼料）、`Startled`（沿沙床逃開）。
紫雷達（purple_firefish）：`Hovering`、`Hiding`、`Sleeping`。
黃金吊（yellow_tang）：`Cruising`（游）、`Grazing`（嘴貼岩石啃，有 `contact_x/contact_y`）、`Resting`（多半在夜裡），以及互動造成的 `Feeding`、`Startled`、`Curious`。
舊檔專用（threadfin，只可能出現在 `archive`）：`Swimming`、`Displaying`；（hatchet）`Surface feeding`。
舊檔專用（蝦，只可能出現在 `archive`）：`Grazing`、`Settling`、`Exploring`、`Retreating`、`Molting`。
舊檔專用（花園鰻，只可能出現在 `archive`）：`Swaying`、`Retracted`、`Sleeping`。
`Sheltering` 在 stage 有列出，但目前 backend 不會設定（`exposure()` 已隨捕食移除）。

## 呈現唯讀

`snapshot()`、`events_after()`、`counts()`、`natural_light()`、`sub_light()`、`biofilm_max()`、`animal_scale()` 及讀取 `state.animals/archive/recent`（選取資訊面板）不消耗 RNG、不改 `export_state()` 位元組（`test_presentation.gd` 驗證）。選取、zoom、viewing light 都在前端，backend 沒有對應狀態。
（`main.gd` 的 `_update_biological_clock()` 會把系統時間寫入 `state.light_hour`，那是生物時鐘，不是 viewing light。）

## 珊瑚礁陣容（2026-09-24，使用者決定；2026-09-25 起最終四物種，花園鰻移除）

四個物種都吃自然食物就能活；欄位都在 `animals[]` 裡。畫面座標同樣是世界座標 1280×720，沙床 `StreamWorld.floor_y(x)`。

### 草食鳚 `lawnmower_blenny`（*Salarias fasciatus*，吃 `biofilm`）
- **永遠在沙床上**：`y == floor_y(x)`，x 在 130–1150。`vx/vy` 就是每 tick 的位移（沿著床面起伏）。
- `Grazing`（原地低頭啃，6–20 秒）、`Perching`（撐著胸鰭停著，4–12 秒）、`Hopping`（沿床面跳 20–90 px，尾巴一甩最快 45 px/s 再滑行減速落地，見「自然游動欄位」；backend 的 y 仍貼床面，**跳的弧線請前端自己畫**）、`Sleeping`（夜裡原地不動）。跳的方向會避開 120 px 內的另一隻 blenny；不在有紫雷達的洞口 104 px 內停下。
- 餵食：飼料**沉到床面後**（`settled:true`），260 px 內、吃得下的 blenny 會 `Feeding` 跳過去啄（`food_id` 指向那粒）。
- 敲玻璃：範圍內的 blenny `Startled`，沿床面往反方向竄開（90 px/s）3 秒。游標引魚：**不理會**。
- 出生：母親旁 ±30 px 的床面上；移入：x=130 或 1150 的床面上。

### 紫雷達 `purple_firefish`（*Nemateleotris decora*，label `"Purple firefish"`，吃 `microfauna`）
（取代紅雷達 `firefish`／*N. magnifica*；行為不變，下文照舊。）
- **自己的沙洞**：`StreamWorld.FIRE_BURROWS` = **650、540、760、410**（2026-09-25 改；原本 420/452/388/484 只差 32 px，成魚圖 91 px 長，同方向時會疊在一起）。從第一格（650）開始、離親代最近的空洞先用，開場兩隻在 650 和 540。洞口彼此至少差 110 px（成魚 91 px ＋ 19 px 間隔），懸停中的成魚（`hover_y` 24–40 的任何高度）不會互相重疊；每個洞口都在核可背景的空沙地上（沙地 x 210–440、505–940，沿 `floor_y` 量），離黃金吊每個岩石點與啃食位置都超過 48 px，懸停的紫雷達也不會和啃食中的黃金吊身體重疊（測試用 `ReefRig.LOOK` 的圖框檢查）。410 在左礁石腳下的沙地，只有第 4 隻才會用到。最多 4 隻。`x/y` = 洞口、`vx=vy=0`、不會有 `relocated_at`。
- `hover_y`：每隻固定 24–40 px。`Hovering`＋`extend:1`＝白天懸停在洞口上方 `hover_y` 處（前端可加一點左右飄動）；`Hiding`＋`extend:0`＝鑽回洞裡；`Sleeping`＋`extend:0`＝夜裡在洞裡。
- 什麼時候躲：chromis 或黃金吊從洞口左右 48 px、上方 200 px 內經過（`FIRE.dx`/`FIRE.dy`，原本叫 `EEL_WARY`，數值不變），或 blenny 在 48 px 內 `Hopping`/`Startled`/`Feeding` 經過 → `Hiding` 6 秒（`FIRE.seconds`）；敲玻璃打到 → `Hiding` 5 秒（`STARTLE.eel_seconds`，名字沿用）。
- 餵食：懸停中、吃得下時，叼走洞口左右 22 px（`FOOD.eel_dx`）、上方 80 px（`FOOD.eel_reach`）內漂過的飼料；每一口一筆 `ate`。游標引魚：**不理會**。
- 出生：離親代的洞最近的空洞；滿 4 隻時 `dispersal`。

### 綠光鰓雀鯛 `green_chromis`（*Chromis viridis*，吃 `microfauna`）
- 水層 `DEPTH.green_chromis` = 180–430（永遠在裡面）。**成群**：id 最小的 chromis 是領頭魚（前端要的話可以自己算 `min(id)`，backend 沒有另外的欄位），牠決定去哪、何時停；其他成員各自有固定的位置（依 id 的黃金角方向、半徑 34–80 px、垂直壓扁一半、跟著領頭魚的朝向 `direction` 左右鏡像），離位超過 120 px 會加速 1.8 倍趕回來。成員彼此保持 36 px。
- 實測（seed 42/812/240921，白天 10 分鐘）：成員到群中心平均 37–40 px；群中心 10 分鐘橫越 907–936 px；領頭魚在游時 88–93% 的 tick 有 ≥4/5 成員同向。
- `Schooling`（在游）、`Resting`（領頭魚停下、成員也就位後一起停；夜裡多半在停）。
- 餵食：各自去追 260 px 內、還在下沉的飼料（`Feeding`，`food_id`），吃完回到隊伍。
- 敲玻璃：範圍內的成員各自 `Startled` 往反方向衝 3 秒（散開），之後回隊伍（重新聚集）。
- 游標引魚：只有領頭魚會 `Curious` 過去看（lure 剛出現時牠會在 1 秒內重新決定，之後每 5 秒再看一次，直到過了 45 秒），成員跟著領頭魚，所以整群會靠過來。
- 死亡：領頭魚死了，下一個最小 id 接手，群繼續。

### 黃金吊 `yellow_tang`（*Zebrasoma flavescens*，label `"Yellow tang"`，吃 `biofilm`）
- 池裡**最大**的魚（`body` 1.4；其他 0.5–0.9），活最久（540 天 ±15%）、120 天成熟、繁殖最慢；開場兩隻都是成魚。最多 2 隻（「一小群、不擋畫面」）。
- 水層 `DEPTH.yellow_tang` = 120–540（永遠在裡面）。`x/y` 是**身體中心**。
- `Cruising`：在上中層（y 150–360）來回游，常橫越整個池子；和另一隻黃金吊的身體保持不重疊（見「自然游動欄位」，原本的 70 px 間距已取代）。
- `Grazing`：游到一個岩石點停住啃 8–20 秒。這時 snapshot 有 `contact_x/contact_y`＝**嘴碰到岩石的點**，身體中心在它旁邊 `TANG.reach × animal_scale`（成魚 61 px＝半個身長 122/2，幼魚 30.5 px）的開放側、同一高度，`direction` 朝向岩石（`direction == -side`），`heading` 也轉到朝岩石（cos 誤差 ≤ 0.1）。所以魚是**側面**貼著岩石，嘴剛好碰到 `contact`：前端**不需要**把身體沿深度壓扁去搆岩石，照原比例畫、做啄的動作即可（2026-09-26 使用者：啃食時看起來被壓扁；原本 22 px）。**兩隻不會同時啃會互相重疊的點**（2026-09-25）：另一隻正在用或正要去的位置在 `TANG.clear`＝130×92 px（成魚圖 122×87 加間隔）以內的點都不選，所以點 3/4（右礁石）互斥；啃食中的黃金吊也不再被經過的另一隻推離岩石。
- `Resting`：夜裡大多停著（白天偶爾），速度很慢；夜裡也只做短程游動。
- 餵食：像 chromis，去追 260 px 內還在下沉的飼料（`Feeding`、`food_id`）。敲玻璃：`Startled` 往反方向衝 3 秒（留在水層內）。游標引魚：會 `Curious` 過來看（每隻各自決定）。
- 紫雷達把低空經過的黃金吊當成 chromis（同一條 `FIRE.dx/dy` 規則）。

### 放置與接觸點（每個物種碰到沙床／岩石／洞口的地方）

世界座標 1280×720，沙床高度 `StreamWorld.floor_y(x) = 597 + 9 sin(0.006x) + 3 sin(0.017x)`。核可的背景 `artifacts/reef-review/background-normal.png` 是 640×360，座標 ×2 就是世界座標。

| 物種 | backend 的 `x/y` 是什麼 | 接觸點 |
|---|---|---|
| 割草機鳚 | `(x, floor_y(x))`：**腹部貼床面的點**，不是身體中心 | 腹鰭／胸鰭撐在這一點；`Hopping` 的弧線前端畫，落點仍是床面。x 130–1150。 |
| 紫雷達 | 洞口 `(burrow_x, burrow_y)`，永遠不動 | 洞口在沙面上（`FIRE_BURROWS` = 650/540/760/410，彼此 ≥ 110 px）；出洞時身體中心在洞口正上方 `hover_y × extend`。 |
| 綠光鰓雀鯛 | 身體中心，水層 180–430 | 不碰任何東西。 |
| 黃金吊 | 身體中心，水層 120–540 | 只有 `Grazing` 時：嘴在 `(contact_x, contact_y)`，身體中心在 `(contact_x + side × 61 × animal_scale, contact_y)`（容許 6 px：到點判定 5 px 加滑行）。 |

黃金吊的岩石點 `StreamWorld.TANG.spots`（`[x, y, side]`，`side=+1`＝魚在岩石右邊、朝左；`-1`＝魚在左邊、朝右），依核可背景的岩石位置放：

| 點 | 世界座標 | 背景上的位置 |
|---|---|---|
| 1 | (170, 318)，side +1 | 左邊大礁岩頂部靠左的岩面（背景約 (85, 159)）；成魚身體中心 (231, 318) |
| 2 | (310, 400)，side +1 | 左礁岩上層平台的右緣（背景約 (155, 200)）；成魚身體中心 (371, 400) |
| 3 | (962, 532)，side −1 | 右邊小礁石的左側岩面（背景約 (481, 266)）；成魚身體中心 (901, 532) |
| 4 | (1048, 496)，side −1 | 右邊大礁石的左側岩面（背景約 (524, 248)）；成魚身體中心 (987, 496) |

2026-09-26 依 61 px 身體距離、對照核可背景 `artifacts/reef-review/background-normal.png`（1280×720 世界座標）重新檢查：
- 原本的點 3 (240, 472)（左礁岩下半部）**刪掉**：身體中心移到 61 px 外之後，整條魚疊在左礁岩的層狀平台上（在岩石裡）。左礁岩其他平台尖端（約 (394, 434)、(476, 460)）都會讓啃食中的黃金吊落在紫雷達洞口 410 或 540 正上方（`FIRE.dx`＝48 px、`FIRE.dy`＝200 px 內），害牠一直躲回洞裡，所以不換位置、直接少一個點。
- 原本的點 5 (1080, 486) 在大礁石**頂上**，61 px 時頭半身疊進岩石；改到同一塊岩石的左側面 **(1048, 496)**。
- 點 1、2、3（原 4）不變：成魚與幼魚的身體都在水裡、在水層 120–540 內。點 2 的成魚中心 (371, 400) 離洞口 410 橫向 39 px，但高度差 204.6 px > `FIRE.dy`，不會觸發躲藏。
- 互斥：點 3/4（右礁石）的啃食位置太近（成魚身體會疊），backend 不會讓兩隻同時用；點 1/2 相距 140 px，可同時用。左右各還能同時有一隻在啃。
- 載入舊存檔時若黃金吊正啃著已刪除或已移動的點（`contact_x/contact_y` 對不上），牠照舊停在原位，最多 20 秒後重選，之後只用新點。

**如果正式背景的岩石位置不同，告訴 Claude 新座標，由 backend 改 `TANG.spots`**（不要前端自己挪魚）。

### 外觀與生命階段欄位（全部物種共用）
- `species`、`name`、`sex`（`"female"`/`"male"`）、`age`（天）、`body`（成長中的體型，成體 = `SPECIES[species].body`）、`hunger`（0–1）、`direction`（±1，朝向）。
- 幼體／成體：`age < SPECIES[species].mature` 是幼體；`world.animal_scale(a)` 回傳 0.5（幼體）或 1.0，純讀取。
- 相對體型（成體 `body`）：黃金吊 1.4 > 割草機鳚 0.8 > 紫雷達 0.5 = 綠光鰓雀鯛 0.5。這是生態用的量，不是像素；畫面比例照真實體型（黃金吊最大、光鰓魚最小），由前端決定。
- 沒有顏色／花紋欄位（`tint` 只屬於舊檔的蝦）。

### Codex 要畫的東西（2026-09-25 更新）
- 花園鰻已從 backend 移除：活的個體不會再出現。舊存檔載入時的鰻 `departure` 是 `live:false`，不用演出。
- 紫雷達洞口位置改了（650/540/760/410），前端照 `burrow_x/burrow_y` 畫即可，不需要改座標。
- 開場是 12 隻（6 隻 chromis）；`tests/test_reef_animation.gd` 目前已改成 `world.state.animals.size()`（Codex 的修改）。
- 新事件 `ate`：用它精確演出「誰咬了哪一粒」，取代「飼料在附近消失就當成咬」的推測。

### Codex 要畫的東西（2026-09-24 當時，backend 已提供）
1. 五個物種的 rig：blenny（貼床面、跳的弧線、啃/停/睡姿勢）、紫雷達（依 `extend`＋`hover_y` 在洞口上下、洞口本身）、chromis（成群游、停）、黃金吊（游、嘴貼 `contact` 啄岩、停）、garden eel。
2. stage 的 `PRESENTED_SPECIES` 要加入 `lawnmower_blenny`、`purple_firefish`、`green_chromis`、`yellow_tang`、`garden_eel`；目前新陣容不會被畫出來，但也不會當掉。**`firefish` 這個鍵已經不存在，不要再用。**
3. 紫雷達的沙洞區（x 388–484）要在背景上看得出來，和鰻洞區分開；黃金吊的五個岩石點要落在畫出來的岩面上（見上表）。
