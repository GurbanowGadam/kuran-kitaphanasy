# Reader scroll-session policy

Requested behavior: restarting the app or returning from a real background session restores only the last selected page's intra-page position. Other pages start at the top. During uninterrupted foreground reading, the existing bounded 24-entry numeric LRU still supports back-and-forth navigation.

## Implementation

- ReaderPreferences version1 remains compatible. Restore directly selects only the saved zero-based page's one-based offset key; other legacy offsets are ignored, without resetting font/mode/theme or bookmarks.
- toJson emits exactly the current page offset, not the session LRU. Reader.persist no longer copies that LRU before serialization. The existing 350ms debounce, ordered writes and lifecycle flush remain.
- hidden/paused/detached mark a new session boundary. On resumed, keep only the current offset and increment a generation. inactive/resumed alone does not clear history.
- ReaderPageScroll disables Flutter PageStorage offset retention. Mounted pages reset to their current generation's initial offset after layout while keeping their subtree/GlobalKeys stable. Unmounted pages initialize lazily. The full604-page book is not created or traversed by this operation; memory clearing is bounded by the24-entry LRU.
- Existing vertical-flow/current-page restoration and the rest of reader settings remain protected by the full regression suite.

## Verification

Behavioral RED was observed for old multi-page persistence and warm-session restoration. New coverage verifies cold widget restart, paused/hidden/detached resume, inactive transitions, foreground retention and legacy preference migration. Parent independently ran the final full suite:213 passed,12 optional tests skipped. flutter analyze: No issues found.

An unrelated pre-existing synthetic audio fixture intermittently generated ZIP bytes twice across a ZIP timestamp boundary, causing an expected SHA to differ from delivered fixture bytes. A three-second boundary test reproduced this deterministically; catalog and fake transport now share one frozen synthetic archive. Production audio code/catalog and integrity checks were not changed.

Updated ARM64 debug APK built and installed with adb install -r on Samsung SM-A155M R58X90JBTRP. Launch returned Status:ok. App data was not cleared; the570-package published catalog is unchanged and was verified inside the APK.

Physical scroll/background/restart UI acceptance was NOT completed: fresh UIAutomator snapshots contained only com.android.systemui because the phone screen was locked. The reader had not been opened, so legacy stored history could legitimately remain on disk until the next reader save; restore already filters that history in memory. No lock bypass was attempted. Automated real-widget restart/session behavior passed as above.

Artifact: /home/gadamgurban/kuran-kitaphanasy/releases/reader-position/kuran-kitaphanasy-reader-position-debug.apk
Logs: /tmp/reader-scroll-parent-tests.log, /tmp/reader-scroll-parent-analyze.log, /tmp/reader-scroll-parent-build.log, /tmp/reader-scroll-red.log
