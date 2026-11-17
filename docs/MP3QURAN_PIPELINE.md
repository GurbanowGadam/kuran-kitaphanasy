# MP3Quran full-Quran release pipeline

Current release root: /home/gadamgurban/kuran-mp3quran-v0.0.1-full
Historical 15-surah preparation: /home/gadamgurban/kuran-mp3quran-v0.0.1

The full release is five selected reciters × all114 surahs =570 immutable original full-surah recordings, in deterministic ZIP_STORED packages containing one SSS.mp3 each. Each reciter has6236 canonical ayahs. Source MP3 bytes total7288832352; ZIP bytes7288896192. Maher retains source person102/moshaf133 Mojawwad, exactly matching the chosen official timing read. Do not silently replace it with his different performance. No splitting/transcoding, opening substitution or fabricated Drive IDs.

## Tools and local expansion

Python3 standard library plus ffprobe:

    python3 -m unittest discover -s tools/tests -p 'test_mp3quran*.py'
    python3 -m unittest tools.mp3quran.test_discover_full_contract
    python3 tools/mp3quran/discover_full_contract.py --help
    python3 tools/mp3quran/expand_full_quran.py --help
    python3 tools/mp3quran/import_drivemap.py --root /home/gadamgurban/kuran-mp3quran-v0.0.1-full --local-only

The full metadata contract derives counts from actual Diyanet surah metadata, captures recording-bound official timings and512-byte Range evidence for every pair, and records measured total sizes. expand_full_quran.py --local writes durable ZIPs to the full root, reuses hash/identity-matching old archives, uses bounded temporary storage/two workers, and resumes from verified records plus actual archive bytes. Full scope is enforced at570 unique pairs, not merely a demo aggregate. Local preparation does not require a server.

refresh_metadata.py is a source-only revalidation tool for existing ZIPs/provenance, without source downloads/repacking. Do not run a pending-candidate refresh over the published catalog. Old FAILED evidence may remain historical/superseded; authoritative current failure lists are in verification-summary.json and the actual publication logs. SHA256SUMS covers release-root files except itself and must be refreshed after README/report edits.

## Unchanged timing policy

original-starts-eof-500ms-v1 preserves every original official marker. Starts must be inside actual ffprobe duration; coverage, ordering and nonoverlap are strict. Nonfinal ends have no tolerance. Only the final canonical end may exceed EOF by at most500ms inclusive;501ms fails. Playback partitions use official STARTS and actual final EOF, not rewritten official ends. Declaration, raw capture/hash, inline metadata and warning summary must agree.

The full corpus has ten final-end warnings, exact deltas53–424ms, listed with original endpoints and actual durations. They are documented source annotations, not hidden corrections. No independent acoustic audit of all recordings is claimed.

## Drive inventory and verified publication

The user added495 missing ZIPs inside the same five existing Drive reciter folders; prior75 IDs/hashes were preserved. Current folder:
https://drive.google.com/drive/folders/1Ju0a7zKN_mySZdZavuCVND-ieSSrSpK_

Public folder HTML exposes only the first50 items;114-file child folders require all continuation pages. discover_drive_map.py consumes a current observed read-only public list URL via temporary --list-url-file, follows bounded pagination, and rejects wrong parents/MIME/names/sizes, duplicates or missing/extra pairs. Public frontend key/cookies must not be embedded in application code or persisted in evidence. The output drive-map.full.json contains only genuine package paths and Drive IDs.

    python3 tools/mp3quran/import_drivemap.py --root /home/gadamgurban/kuran-mp3quran-v0.0.1-full --map /home/gadamgurban/kuran-mp3quran-v0.0.1-full/drive-map.full.json --output /home/gadamgurban/kuran-mp3quran-v0.0.1-full/audio_catalog.published.json --workers 3

Large files return a normal Drive HTML confirmation form. drive_download.py accepts only bounded same-ID trusted HTTPS Drive forms/redirects, retries transient failures, streams one bounded temporary ZIP per worker, and checks actual byte size/ZIP signature. The publication gate independently computes SHA256 against the audited source. Each successful complete download writes non-secret evidence under provenance/drive-verification; no prior75 skip/resume is assumed. Any failure refuses publication after other queued jobs finish.

Only after ALL570 real downloads/hashes pass is the explicit separate published JSON atomically written. The source candidate remains pending/null-ID and immutable. The CLI never edits assets/data/audio_catalog.json itself; activation is a separately verified copy after success, with before-full snapshots retained. --local-only never writes/marks a catalog or accesses the network.

This full publication completed successfully:570/570 remote hashes matched and the resulting catalog is active. APK and AAB embedded catalog bytes also match the active JSON. See docs/OFFLINE_AUDIO.md and releases/0.0.1/README_TR.md for actual tests, native-device evidence, source rights and the remaining owner-signing requirement.
