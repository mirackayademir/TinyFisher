TinyFisher HQ 20-100m canyon runtime payload

Source format: WebP lossless (VP8L)
RIFF total size: 107932 bytes
Source dimensions: 2048 x 682
Visible crop: rows 27..681 (top 27 rows are transparent)

Correct payload order used by scenes/underwater_terrain_runtime.gd:
part_00.txt
part_01.txt
part_02a.txt
part_02b.txt
part_03.txt
part_04.txt
part_05.txt
part_06.txt
part_07.txt

IMPORTANT:
- part_02.txt is an obsolete damaged/overlapped transfer and MUST NOT be used.
- part_02a + part_02b are the verified replacement split.
- The runtime reads the RIFF size from the WebP header and trims any trailing transfer characters after the exact source-file boundary before decoding.
- Runtime mapping is world-anchored and targets the live 20m..100m hook-depth band.
