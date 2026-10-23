# Save freshness adoption gates

Source f4053597d03b99a61cb97e2eef1ec64ed174f22a, branch codex/save-continue. Exact native-tested SaveSession and DataStoreBackend modules adopted, with 111 adapter/session regression assertions added to the existing state suite. Expected full count: 76 suites / 468225 assertions. Expected numbers are not completed gates.

Windows full handle95443 runs an immutable Git archive; windows-full-start.json records its exact input hashes. windows-full-process.json exists only after terminal completion. Do not restart or duplicate this run. Linux is the single push-triggered workflow for the exact source; locate-ci.py discovers it without dispatch, and fetch-ci.py preserves terminal successful raw logs and metadata. A pending/failed run is not success.

The adopted state suite passed1124/0 in the focused run. The private candidate evidence and baseline counterexample are documented in ../save-slot-isolation/SESSION-CACHE.md, with a byte-bound verifier. Studio passed111 assertions with224 sources/zero CreatorErrors against a fake cached datastore; all production scripts disabled. Actual API options were used, but no live DataStore request was made. Diagnostic closed/restored. Ordinary cached read remains available; SaveSession's three rest observation paths explicitly use readFresh.

Nothing published. Progress import and production archive integration remain unfinished. Main/laptop synchronization, full game lifecycle/streaming/device/performance, online durability and release checks remain open.
