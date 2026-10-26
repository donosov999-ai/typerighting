"""Verify task coverage, not feature completion. No network or user data."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
reference = Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024')
coverage = json.loads((root / 'docs/full-transfer-coverage-20261026.json').read_text())
receipts = json.loads((root / 'docs/full-transfer-task-readback-20261026.json').read_text())
tasks = json.loads((root / 'docs/full-transfer-tasks-20261026.json').read_text())
expected_screens = set(re.findall(r'\| ([A-L]\d) \|', (reference / 'SCREEN_ATLAS.md').read_text())) | {'M1', 'M2', 'M3', 'M4'}
expected_groups = set(range(1, 60))
assert len(expected_screens) == 71
assert set(coverage['screenTasks']) == expected_screens
assert {int(x) for x in coverage['functionTasks']} == expected_groups
assert all(coverage['functionTasks'].values())
assert len(tasks['newTasks']) == 19
assert {t['id'] for t in tasks['newTasks']} == {t['id'] for t in receipts['tasks']}
assert all(t['executor'] == 'typerighting-codex-mac' and t['descriptionPresent'] for t in receipts['tasks'])
known_ids = {t['id'] for t in tasks['newTasks']} | {t['id'] for t in tasks['existingTaskIndex']}
assert all(i in known_ids for ids in coverage['functionTasks'].values() for i in ids)
assert all(i in known_ids for i in coverage['screenTasks'].values())
ledger = (root / 'FULL_TRANSFER_SCOPE_20261026.md').read_text()
assert all(t['id'] in ledger for t in tasks['newTasks'])
print('PASS: 19 server-read-back tasks; 59/59 groups and 71/71 screens assigned. Implementation completion is NOT implied.')
