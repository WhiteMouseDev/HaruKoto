"""Convert the pinned StrokeSVG kana into native Flutter Path calls.

Run python3 tool/generate_kana_textbook_paths.py <local strokesvg/dist> from
apps/mobile, then dart format lib/features/kana/domain/kana_*_textbook_paths.dart.
Use StrokeSVG commit e4c2c91034e03c9c2f4e95f14f2361a948f52cd0.
"""
import argparse
import re
import xml.etree.ElementTree as ET
from pathlib import Path


def pair(x, y):
    return f'const Offset({x}, {y})'


def path_calls(path, *, filled, indentation):
    tokens = re.findall(r'[a-zA-Z]|-?\d+(?:\.\d+)?', path)
    offset = 0
    command = None
    x = y = x0 = y0 = 0
    qx = qy = cx = cy = None
    calls = []
    while offset < len(tokens):
        if tokens[offset].isalpha():
            command = tokens[offset]
            offset += 1
        assert command
        kind = command.lower()
        relative = kind == command
        size = {'m': 2, 'l': 2, 'h': 1, 'v': 1, 'q': 4, 't': 2, 'c': 6,
                's': 4, 'a': 7, 'z': 0}[kind]
        values = list(map(int, tokens[offset:offset + size]))
        assert len(values) == size
        offset += size
        if kind == 'z':
            calls.append('close()')
            x, y = x0, y0
            command = None
        elif kind == 'a':
            rx, ry, rotate, large, clockwise, dx, dy = values
            assert rx == ry and not rotate and large in (0, 1) and clockwise in (0, 1)
            func = 'relativeArcToPoint' if relative else 'arcToPoint'
            options = f'radius: const Radius.circular({rx})'
            if large:
                options += ', largeArc: true'
            if not clockwise:
                options += ', clockwise: false'
            calls.append(f'{func}({pair(dx, dy)}, {options})')
            x, y = (x + dx, y + dy) if relative else (dx, dy)
        elif kind in ['h', 'v']:
            if relative:
                dx, dy = (values[0], 0) if kind == 'h' else (0, values[0])
                calls.append(f'relativeLineTo({dx}, {dy})')
                x += dx
                y += dy
            else:
                x, y = (values[0], y) if kind == 'h' else (x, values[0])
                calls.append(f'lineTo({x}, {y})')
        else:
            base_x, base_y = (x, y) if relative else (0, 0)
            xx, yy = (base_x + values[-2], base_y + values[-1])
            if kind == 'm':
                if filled and calls and calls[-1] != 'close()':
                    calls.append('close()')
                calls.append(f'moveTo({xx}, {yy})')
                x0, y0 = xx, yy
                command = 'l' if relative else 'L'
            elif kind == 't':
                qx, qy = (x, y) if qx is None else (2 * x - qx, 2 * y - qy)
                calls.append(f'quadraticBezierTo({qx}, {qy}, {xx}, {yy})')
            elif kind == 's':
                first_x, first_y = (x, y) if cx is None else (2 * x - cx, 2 * y - cy)
                cx, cy = base_x + values[0], base_y + values[1]
                calls.append(f'cubicTo({first_x}, {first_y}, {cx}, {cy}, {xx}, {yy})')
            else:
                absolute_name = {'l': 'lineTo', 'q': 'quadraticBezierTo', 'c': 'cubicTo'}[kind]
                name = f'relative{absolute_name[0].upper()}{absolute_name[1:]}' if relative else absolute_name
                calls.append(f'{name}({", ".join(map(str, values))})')
                if kind == 'q':
                    qx, qy = base_x + values[0], base_y + values[1]
                if kind == 'c':
                    cx, cy = base_x + values[2], base_y + values[3]
            x, y = xx, yy
        if kind not in ['q', 't']:
            qx = qy = None
        if kind not in ['c', 's']:
            cx = cy = None
    if filled and calls[-1] != 'close()':
        calls.append('close()')
    return '\n'.join(f'{" " * indentation}..{call}' for call in calls)


def paths(replay, outlines, clips, indent, affine):
    clip = re.fullmatch(r'url\(#([^)]+)\)', replay.get('clip-path', ''))
    assert clip is not None, replay.attrib
    outline = outlines[clips[clip[1]]]
    return (source_path('outline', outline, True, indent, affine)
            + source_path('replayPath', replay, False, indent, affine))


def source_path(name, node, filled, indent, affine):
    scale, x, y = affine
    translate = node.get('transform')
    if translate:
        match = re.fullmatch(r'translate\(([-.\d]+) ([-.\d]+)\)', translate)
        assert match is not None, translate
        x += float(match[1]) * scale
        y += float(match[2]) * scale

    pad = ' ' * indent
    if (scale, x, y) == (1, 0, 0):
        calls = path_calls(node.get('d'), filled=filled, indentation=indent + 2)
        return f'{pad}{name}: Path()\n{calls},\n'

    calls = path_calls(node.get('d'), filled=filled, indentation=indent + 4)
    return (f'{pad}{name}: _transformSourcePath(\n{pad}  Path()\n{calls},\n'
            f'{pad}  {scale}, {pair(x, y)},\n{pad}),\n')

HIRAGANA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
KATAKANA = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン'
HIRAGANA_VARIANTS = 'がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽゔぁぃぅぇぉっゃゅょゎ'
KATAKANA_VARIANTS = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポヴァィゥェォッャュョヮヵヶ'

# These small kana have no authored source SVG. Fit and origin are the rounded
# median measurements of the authored large/small pairs for each script.
DERIVED_SMALL = {
    'っ': ('つ', (0.76, 119, 240)),
    'ゎ': ('わ', (0.76, 119, 240)),
    'ッ': ('ツ', (0.77, 117, 220)),
    'ヮ': ('ワ', (0.77, 117, 220)),
    'ヵ': ('カ', (0.77, 117, 220)),
    'ヶ': ('ケ', (0.77, 117, 220)),
}


def generate(source, glyphs, script, markers):
    result = """// Generated by tool/generate_kana_textbook_paths.py.
part of 'katakana_textbook_example.dart';

// Adapted from Klee One based StrokeSVG data at
// https://github.com/zhengkyl/strokesvg/tree/e4c2c91034e03c9c2f4e95f14f2361a948f52cd0/dist
// Copyright 2020 The Klee Project Authors. See assets/licenses/strokesvg.txt.
"""
    result += f'final _{script}Examples = <String, KatakanaTextbookExample Function()>{{\n'
    for glyph in glyphs:
        if glyph == 'ゔ':
            result += """  // StrokeSVG has no ゔ. Use う with the authored dakuten from ヴ.
  'ゔ': () => KatakanaTextbookExample([
    ...kanaTextbookExample('う')!.strokes,
    ...kanaTextbookExample('ヴ')!.strokes.skip(3),
  ]),
"""
            continue

        source_glyph, affine = DERIVED_SMALL.get(glyph, (glyph, (1, 0, 0)))
        if source_glyph != glyph:
            result += f'  // Small form derived from {source_glyph}.\n'
        file = source / script / f'{source_glyph}.svg'
        if not file.exists():
            file = source / f'{source_glyph}.svg'
        root = ET.parse(file).getroot()
        assert root.get('data-strokesvg') == source_glyph, file
        assert root.get('viewBox') == '0 0 1024 1024', glyph
        groups = {g.get('data-strokesvg'): g for g in root if g.tag.endswith('}g')}
        assert groups['strokes'].get('style') == (
            'stroke:var(--stroke,#000);fill:none;stroke-width:128;stroke-linecap:round'
        ), glyph
        outlines = {p.get('id'): p for p in groups['shadows'].iter() if p.tag.endswith('}path')}
        assert all(len(clip) == 1 and clip[0].tag.endswith('}use') for clip in root[0]), glyph
        clips = {clip.get('id'): clip[0].get('href')[1:] for clip in root[0]}
        assert set(outlines) == set(clips.values()), glyph
        result += f"  '{glyph}': () => KatakanaTextbookExample([\n"
        marks = markers[glyph]
        assert len(marks) == len(groups['strokes']), glyph
        for index, stroke in enumerate(groups['strokes']):
            assert stroke.get('style') == f'--i:{index}', glyph
            start_x, start_y, number_x, number_y = marks[index]
            if stroke.tag.endswith('}g'):
                result += '    KatakanaTextbookStroke.grouped(\n      parts: [\n'
                for replay in stroke:
                    result += '        KatakanaTextbookStrokePart(\n'
                    result += paths(replay, outlines, clips, 10, affine)
                    result += '        ),\n'
                result += '      ],\n'
            else:
                result += '    KatakanaTextbookStroke(\n'
                result += paths(stroke, outlines, clips, 6, affine)
            result += f"""      start: {pair(start_x, start_y)},
      numberPosition: {pair(number_x, number_y)},
    ),
"""
        result += '  ]),\n'
    return result + '};\n'


def read_markers(file):
    markers = {}
    for line in file.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        glyph, *values = line.split()
        assert len(glyph) == 1 and glyph not in markers, line
        markers[glyph] = [tuple(map(int, item.split(','))) for item in values]
    return markers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='dist directory from the pinned StrokeSVG commit')
    parser.add_argument(
        '--markers', type=Path, default=Path(__file__).with_name('kana_stroke_markers.tsv'),
    )
    parser.add_argument(
        '--output-dir', type=Path,
        default=Path(__file__).resolve().parents[1] / 'lib/features/kana/domain',
    )
    args = parser.parse_args()
    markers = read_markers(args.markers)
    for script, glyphs in [('hiragana', HIRAGANA + HIRAGANA_VARIANTS),
                           ('katakana', KATAKANA + KATAKANA_VARIANTS)]:
        result = generate(args.source, glyphs, script, markers)
        output = args.output_dir / f'kana_{script}_textbook_paths.dart'
        output.write_text(result, encoding='utf-8')


if __name__ == '__main__':
    main()
