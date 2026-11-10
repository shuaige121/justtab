#!/usr/bin/env python3
"""Check launch-copy character counts using only the Python standard library."""
import re
from pathlib import Path

source = Path(__file__).with_name('launch-posts.md').read_text()
pattern = re.compile(
    r'<!-- count: (.+?); max: (\d+) -->\n```text\n(.*?)\n```\n\((\d+)/(\d+)\)',
    re.DOTALL,
)
items = pattern.findall(source)
assert len(items) == 10, f'Expected 10 length-limited items, found {len(items)}'
print('| Item | Characters / limit |')
print('| --- | --- |')
for label, limit, copy, printed_count, printed_limit in items:
    count = len(copy)
    assert count == int(printed_count), f'{label}: printed count is stale'
    assert limit == printed_limit, f'{label}: printed limit is stale'
    assert count <= int(limit), f'{label}: exceeds character limit'
    if label.startswith('X post'):
        url_weighted = len(re.sub(r'https?://\S+', 'x' * 23, copy))
        assert url_weighted <= int(limit), f'{label}: exceeds URL-weighted limit'
    print(f'| {label} | {count}/{limit} |')
