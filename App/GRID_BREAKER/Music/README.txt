GRID_BREAKER — background music
================================

Drop your music files here as .mp3 (e.g. track1.mp3, track2.mp3, track3.mp3).
The file names don't matter.

How it works:
- This whole folder is bundled into the app (it's a folder reference in the Xcode
  project), so any .mp3 you place here is included automatically on the next build
  — no code or project changes needed.
- On each app launch the tracks are shuffled, so a random one starts playing.
- When a track finishes, the next one (in the shuffled order) plays automatically.
  After the last track, the list reshuffles and continues.
- The SOUND ON/OFF toggle on the main menu controls this music (and the SFX).

Notes:
- Use .mp3 files. (Other formats AVAudioPlayer supports — m4a, wav, aac — also work
  if you change the extension filter in MusicPlayer.loadTracks, but .mp3 is the
  default.)
- This README is harmless; it's ignored (only .mp3 files are played).
- After adding files, rebuild the app in Xcode for them to take effect.
