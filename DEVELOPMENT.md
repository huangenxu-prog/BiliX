# BiliX 1.0

Independent SwiftUI iOS Bilibili client prototype.

## Frozen visual direction
- Background #FFFFFF
- Primary text #171717
- Secondary text #8A8A8A
- Dividers #F2F2F2
- Accent #FB7299
- Video player black

## Product priorities
1. Discover/recommendations
2. Search
3. Video playback with fullscreen
4. Playback continuity
5. Local favorites/history
6. Optional danmaku

No download or share features. Do not modify MusicXS2, TingX or BookX.

## Technical notes
BiliPai (https://github.com/jay3-yy/BiliPai) is a research reference, not a directly portable iOS dependency. Any code copied or adapted from GPL-3.0 projects requires appropriate license compliance and attribution. Verify platform API access and authentication before promising playback.

## Build
Install XcodeGen, run `xcodegen generate`, then build the BiliX scheme with Xcode.
