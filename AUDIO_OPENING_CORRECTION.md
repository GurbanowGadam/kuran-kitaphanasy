# Abu Bakr opening correction

The owner reports that Abu_Bakr_Ash-Shaatree_128kbps SSS000 recordings are istiadhah, not besmele, and explicitly authorizes replacing that opening. This correction does not claim independent listening or linguistic verification. Replacement identity is the same reciter's canonical Fatiha 1:1 recording, 001001.mp3.

Source: /home/gadamgurban/kuran-audio-drive-test/Abu_Bakr_Ash-Shaatree_128kbps/001_Fatiha.zip, exact ZIP member 001001.mp3. The extracted 104200 bytes match the existing Abu Fatiha catalog files[001001.mp3] SHA-256:
b72b1275a8db14537557f668735b70a7280c1f7ec83532d159de978e8a3e7023

Bundled unchanged at assets/audio/abu_bakr_fatiha_001001.mp3; no trimming, encoding or transcoding. ffprobe reports duration=6.512500 seconds; durationMs=6513 is rounded to the nearest millisecond.

All 75 original package records retain their archive IDs, ZIP hashes, byte counts, files maps and original durationsMs maps. Only the 14 eligible Abu records gain openingOverride {asset, sha256, durationMs}. Abu has 15 catalog surahs: 1, 56, 67, 75, 93, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114. Surah 1 has no override; surah 9 is not present and remains excluded by playback logic. Other reciters are unchanged.

The original downloaded package remains validated against every original file hash, including SSS000. The verified bundled replacement is materialized atomically under the persistent application's quran_audio/openings/<sha256>.mp3. Existing replacement files are hash checked before queue preparation; corrupt files fail playback rather than being silently used. No Fatiha package download or network stream is required. openingAssetLoader can be injected for tests. Native and legacy players use the same replacement path. timingPrefix substitutes the measured replacement length only for the opening, preserving canonical source durations.

Validation: test/audio_opening_correction_test.dart uses the actual catalog, actual bundled bytes and an existing extracted Abu package with a downloader that fails if called. It verifies all 75 records/15 Abu surahs, opening-prefix timing, exact queued bytes, the 6513ms intro boundary and rejection of a corrupted persistent opening. Existing audio basmala, timing and service tests are also run. Build/install and audible device acceptance belong to the parent task, not this change.
