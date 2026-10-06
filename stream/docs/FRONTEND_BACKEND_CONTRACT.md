# Frontend/backend integration contract

Updated 2026-10-06. Current product scope is the approved four-species reef redesign. Older split-work and cast notes are preserved in [FRONTEND_BACKEND_CONTRACT_HISTORY.md](FRONTEND_BACKEND_CONTRACT_HISTORY.md). The user's whole-app completion request covers both frontend and backend work.

The data contract is [BACKEND_SNAPSHOT_EVENTS.md](BACKEND_SNAPSHOT_EVENTS.md). `StreamStage.apply_snapshot()` accepts a deeply copied read-only dictionary. The stage receives no callable world or shared RNG object. Animation, viewport, pause presentation, environment touch effects and lighting previews cannot change ecology or persisted actor state.

Production presentation supports green chromis, clownfish, seahorse and royal gramma only. Geometry comes from the selected scene and decor. Horse tails clasp the backend hitch location; gramma cave retreat uses its den and clipping, while rock homes stay visible. Clownfish nestling follows its anemone. Chromis night targets and dawn return follow backend state. Fish side mirrors use heading hysteresis and the approved low-pixel art.

World positions are 1280×720, mapped into a 640×360 viewport. Integer display scales, letterboxing, resize and fullscreen preserve pixel alignment. Pointer coordinates are converted through the viewport transform; letterbox clicks are ignored. The app has no animal inspector.

Feeding and tapping are explicit world commands. Scene/decor controls validate their command through the backend; the scene transition lasts 0.75 seconds with relocation hidden at black. Visual ripples and plant motion remain transient presentation effects. Feeding animation consumes unseen live `ate` events, without inferring an eater from disappearing pellets.

The event cursor establishes a baseline on first load, world change or rewind. It ignores historical/offline events. Old-age exit visuals come from `departing` and fade away without sinking. Offline advancement and scene changes clear them. Pausing freezes transient animation; hidden rendering stops while the low-frequency lifecycle loop continues to handle events and persistence.

Focused rendering targets 60 FPS, unfocused 30 FPS, hidden 0 rendered frames with the hidden loop at 10 FPS. These pacing settings require measured native acceptance, including foreground CPU/RSS and background/hidden lifecycle behavior. Headless tests verify contracts and state isolation but do not establish GPU appearance, macOS Cmd-Q or sleep/wake acceptance.

Current verification and remaining app acceptance work are recorded in [APP_COMPLETION.md](APP_COMPLETION.md). README describes current controls, storage and isolated QA entry points.
