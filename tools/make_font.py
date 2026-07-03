#!/usr/bin/env python3
"""同梱フォント（日本語＋絵文字サブセット）の再生成スクリプト。

ゲーム内テキスト（data/*.json, scripts/**/*.gd）に新しい漢字や絵文字を追加したら
これを再実行して ui/fonts/ を更新すること（Webビルドでは同梱フォントしか使えない）。

必要: pip install fonttools brotli
ソースフォント:
  - Noto Sans CJK JP (例: /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc)
  - Noto Color Emoji (例: npm install @fontsource/noto-color-emoji →
      node_modules/@fontsource/noto-color-emoji/files/noto-color-emoji-emoji-400-normal.woff2)

使い方: python3 tools/make_font.py <NotoSansCJK.ttc> <NotoColorEmoji.woff2|ttf>
"""
import glob
import subprocess
import sys
import tempfile

if len(sys.argv) != 3:
    print(__doc__)
    sys.exit(1)

CJK_SRC, EMOJI_SRC = sys.argv[1], sys.argv[2]

chars: set[str] = set()
for p in glob.glob("data/*.json") + glob.glob("scripts/**/*.gd", recursive=True):
    chars |= set(open(p, encoding="utf-8").read())
# 動的表示されうる文字（数字・かな・記号）を範囲ごと追加
for lo, hi in [(0x20, 0x7E), (0xD7, 0xD7), (0x3000, 0x303F),
               (0x3041, 0x3096), (0x30A0, 0x30FF), (0xFF01, 0xFFEE)]:
    chars |= {chr(c) for c in range(lo, hi + 1)}
chars -= set("\n\t\r")

def is_emoji(c: str) -> bool:
    return ord(c) >= 0x1F000 or (0x2600 <= ord(c) <= 0x27BF) or ord(c) in (0x23F0, 0x23F8)

emoji = "".join(sorted(c for c in chars if is_emoji(c)))
text = "".join(sorted(c for c in chars if not is_emoji(c)))

with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as tf:
    tf.write(text)
    text_file = tf.name
with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as ef:
    ef.write(emoji)
    emoji_file = ef.name

subprocess.run(["pyftsubset", CJK_SRC, "--font-number=0",
                f"--text-file={text_file}",
                "--output-file=ui/fonts/noto_jp_subset.otf",
                "--layout-features=*", "--no-hinting", "--desubroutinize"], check=True)
subprocess.run(["pyftsubset", EMOJI_SRC,
                f"--text-file={emoji_file}",
                "--output-file=ui/fonts/noto_emoji_subset.ttf", "--no-hinting"], check=True)
print(f"done. text={len(text)}字 emoji={len(emoji)}字")
