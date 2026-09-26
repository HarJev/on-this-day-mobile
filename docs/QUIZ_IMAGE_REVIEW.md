# MQ5 Image Resource Review

Checked 2026-09-13 against the backend's current nine image-identification URLs.
No backend content, provenance, or resource limits were changed.

| Question ID | Original encoded bytes | Result |
| --- | ---: | --- |
| identify-colosseum | 3,947,925 | Transfer and bounded Flutter decode pass |
| identify-benin-bronze | 17,849,836 | Exceeds 8 MiB; preparation must fail |
| identify-nelson-mandela | 747,220 | Transfer and bounded Flutter decode pass |
| identify-terracotta-army | 487,868 | Transfer and bounded Flutter decode pass |
| identify-mahatma-gandhi | 3,250,029 | Transfer and bounded Flutter decode pass |
| identify-harriet-tubman | 300,897 | Transfer and bounded Flutter decode pass |
| identify-machu-picchu | 11,126,998 | Exceeds 8 MiB; preparation must fail |
| identify-winston-churchill | 1,258,141 | Transfer and bounded Flutter decode pass |
| identify-alan-turing | 92,890 | Transfer and bounded Flutter decode pass |

All originals returned HTTP 200. Oversized originals were rejected from declared
length without downloading them. The seven accepted originals decoded with a
maximum 1024-pixel edge; their combined retained decoded capacity was below
32 MiB. Transfers used a 15-second deadline. Initial sandbox DNS resolution failed;
the permitted network check outside that restriction succeeded.

The two oversized originals were replaced in the backend canonical JSON with
these bounded Commons renditions, while preserving their original
source/attribution/license metadata:

- [Benin Bronze, 960px](https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/At_the_British_Museum_2024_017.jpg/960px-At_the_British_Museum_2024_017.jpg): 351,822 bytes.
- [Machu Picchu, 960px](https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Machu_Picchu%2C_Per%C3%BA%2C_2015-07-30%2C_DD_47.JPG/960px-Machu_Picchu%2C_Per%C3%BA%2C_2015-07-30%2C_DD_47.JPG): 207,136 bytes.

The backend content change must be imported into local PostgreSQL before SAM
serves the updated image URLs. After import, all nine canonical images have a
bounded rendition available to the mobile preparation layer.

## Local Verification

Focused fake-driven preparation and widget tests need no network. Optional
captures use test-generated pixels, not historical placeholders shipped in the
application. They exercise answering, skipped feedback, and 320px/2x text layout.
Native VoiceOver/device rendering and native peak-memory profiling remain for
device integration; widget tests do not prove those properties.

```sh
flutter test test/features/quiz/presentation
flutter test test/features/quiz/presentation/quiz_image_gameplay_test.dart \
  --dart-define=QUIZ_IMAGE_SCREENSHOT_DIR=/tmp/mq5-screenshots
```

The optional screenshot font loader uses macOS system fonts and the installed
Flutter Material icon font. Captures are local artifacts, not checked-in goldens.
To decode previously downloaded originals without fetching during tests, place
accepted files named `mq5-identify-*.img` in a directory and pass
`--dart-define=QUIZ_IMAGE_ASSET_DIR=<directory>` to the preparation tests.
