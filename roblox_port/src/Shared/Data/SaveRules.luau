--!strict
-- Every number and name the persistent saves use (ROBLOX-39): store names, key prefixes, sizes, timings, limits. The logic is in
-- Shared/Persistence/Save*.luau; none of it carries a number of its own. Sizes were measured on real checkpoints (tests/state.luau
-- prints them; docs/HANDOFF-roblox-state.md records them).
local SaveRules = {}

-- ---------------------------------------------------------------- where it is kept
SaveRules.STORE_PRODUCTION = "Windowsill_v1"
SaveRules.STORE_TEST = "WindowsillTest_v1" -- Studio and the test place: Chet's runs never touch a real save
SaveRules.KEY_PROGRESS = "P_" -- P_<UserId>: the player's progress (small, precious)
SaveRules.KEY_REST = "R_" -- R_<UserId>_main, R_<UserId>_free: the last rest of each mode (larger, replaceable)
SaveRules.MODES = { "main", "free" } :: { string }
SaveRules.FORMAT = "the-windowsill save"
SaveRules.REMOTES_NAME = "SaveRemotes" -- the folder in ReplicatedStorage holding ToServer and ToClient

-- ---------------------------------------------------------------- sizes (characters of canonical JSON)
-- Measured: a rest is about 22 thousand characters (tests/state.luau prints the real figures). The cap leaves room for a long life's
-- growth and is far under Roblox's 4,194,304-character limit even with the kept backup inside the same value.
SaveRules.MAX_REST_CHARS = 262144
SaveRules.MAX_REST_NODES = 120000 -- values (tables, numbers, strings) a rest may hold, counted before it is encoded
SaveRules.MAX_DEPTH = 24
SaveRules.MAX_PROGRESS_CHARS = 16384
SaveRules.MAX_VALUE_CHARS = 4194304 -- Roblox's own limit on one stored value
SaveRules.MAX_PROGRESS_NODES = 1500 -- values a progress message may hold, counted before anything reads it
SaveRules.MAX_PROGRESS_DEPTH = 8
SaveRules.MAX_PAGES = 200 -- notebook ids kept (the book has 25 pages; room for the future)
SaveRules.MAX_ID_CHARS = 48
SaveRules.MAX_EYE_SECONDS = 1.0e9
SaveRules.PREF_KEYS = { "FocusToggle", "ReducedMotion", "ShowLastSeen", "AutomaticGrip", "NotebookNotes", "LargeText", "SoundMuted" } :: { string }

-- ---------------------------------------------------------------- timing (seconds)
SaveRules.PROGRESS_DEBOUNCE = 30 -- at most one progress write in this time (events in between are coalesced)
SaveRules.REST_MIN_INTERVAL = 10 -- a key may be written about every 6 s; this leaves room
SaveRules.HEARTBEAT = 30 -- the session lock is refreshed this often
SaveRules.LOCK_STALE = 120 -- a lock older than this may be taken over by a newer session
SaveRules.BACKOFF_BASE = 2
SaveRules.BACKOFF_CAP = 60
SaveRules.RETRY_LOAD = 15 -- a session that could not load or lock tries again this often
SaveRules.FLUSH_ATTEMPTS = 4 -- tries at leaving or shutting down, with the backoff between
SaveRules.FLUSH_BACKOFF = 1
SaveRules.FLUSH_DEADLINE = 24 -- BindToClose has 30 s in all
SaveRules.REQUESTS_PER_MINUTE = 10 -- DataStore requests one player's session may start in a minute (the budget is 60 + 10 per player)

-- ---------------------------------------------------------------- what the client may send (per player)
SaveRules.PROGRESS_BURST = 6
SaveRules.PROGRESS_PER_SECOND = 0.5
SaveRules.REST_BURST = 2
SaveRules.REST_PER_SECOND = 0.2
SaveRules.PROTOCOL = 1 -- the version of the messages between client and server
SaveRules.CLIENT_HELLO_GAP = 2.5 -- the client says hello again this often until the server answers
SaveRules.CLIENT_HELLO_TRIES = 6
SaveRules.CLIENT_PROGRESS_GAP = 2 -- the client sends at most one progress message in this time
SaveRules.CLIENT_EYE_GAP = 30 -- and re-sends the eye-view seconds this often when they changed
SaveRules.CLIENT_WAIT_REMOTES = 1.5 -- the start menu waits this long for the server's remotes to appear
SaveRules.CLIENT_WAIT_REPLY = 4 -- and this long for the first reply after saying hello

-- ---------------------------------------------------------------- words for statuses
SaveRules.STATUS = { saved = "saved", saving = "saving", session = "session" } -- session: this visit only
SaveRules.REASONS = { "offline", "no_api", "load_failed", "other_session", "corrupt", "newer", "write_failed" } :: { string }

return SaveRules
