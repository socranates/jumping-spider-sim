"""Collect a complete native family route; partial lives never qualify."""
from pathlib import Path
import argparse, datetime, hashlib, json, re

p = argparse.ArgumentParser()
p.add_argument('--stage', type=Path, required=True)
p.add_argument('--log', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
ROOT = Path(__file__).resolve().parents[2]
sha = lambda b: hashlib.sha256(b).hexdigest()
m = json.loads((a.stage / 'manifest.json').read_text())
assert m['source_count'] == 276 and not m['published'] and m['storage'] == 'unbound yielding memory only'
assert sha(Path(m['place']).read_bytes()) == m['place_sha256']
assert sha((a.stage / 'guard.luau').read_bytes()) == m['guard_sha256']
assert (a.stage / 'src/Client/MatrixPlayback.luau').read_bytes() == (ROOT / 'docs/generation-route/playback.luau').read_bytes()
assert (a.stage / 'compile.txt').read_text().strip() == 'compile 276/276'
for rel, digest in m['original_sources'].items():
    assert sha((ROOT / 'roblox_port/src' / rel).read_bytes().replace(b'\r\n', b'\n')) == digest, rel
raw = a.log.read_bytes()
events, guards, errors, warnings, kept = [], [], [], [], []
for line in raw.decode().splitlines():
    hit = re.search(r'\[FAMILY_ROUTE_(\w+)\]\s+(\d+)\s+(\{.*\}|\[.*\])$', line)
    if hit:
        events.append(dict(kind=hit[1], run=hit[2], value=json.loads(hit[3]), utc=line.split(',')[0]))
        kept.append(line)
    elif '[MATRIX_GUARD] 276 after full unbound memory_only' in line:
        guards.append(line); kept.append(line)
    elif '[FLog::CreatorError]' in line:
        errors.append(line); kept.append(line)
    elif '[FLog::CreatorWarning]' in line:
        warnings.append(line); kept.append(line)
assert len({e['run'] for e in events}) == 1 and len(guards) == 2 and not errors
assert not any('[Windowsill]' in line for line in warnings)
rows = lambda kind: [e['value'] for e in events if e['kind'] == kind]
assert len(rows('BEGIN')) == len(rows('CLEANUP')) == len(rows('PASS')) == 1
assert not rows('FAIL') and not rows('DEADLINE')
assert len(rows('MEAL')) == 62
assert len(rows('NEXT_MEAL')) == 9
assert len(rows('MOULT_START')) == len(rows('MOULT_END')) == len(rows('HARDENED')) == 9
expected = [('main', 'standard', [7, 10, 5]), ('main', 'gentle', [7, 10, 3]), ('free', 'gentle', [7, 10, 3])]
starts = [i for i, e in enumerate(events) if e['kind'] == 'FRESH']
assert len(starts) == 3
for n, (mode, rules, targets) in enumerate(expected):
    group = events[starts[n]:starts[n + 1] if n < 2 else len(events)]
    values = lambda kind: [e['value'] for e in group if e['kind'] == kind]
    first = group[0]['value']
    generation = first['generation']
    assert first['mode'] == mode and first['rules'] == rules and first['stage'] == 0
    assert first['food'] == first['meals'] == 0 and not first['can_run'] and not first['can_lock']
    assert first['mating'] == 'none'
    meals = values('MEAL')
    assert len(meals) == sum(targets)
    pos = 0
    for instar, goal in enumerate(targets):
        for i in range(1, goal + 1):
            meal = meals[pos]; pos += 1
            assert meal['mode'] == mode and meal['rules'] == rules and meal['stage'] == instar
            assert meal['meals'] == pos and meal['goal'] == goal and meal['ready'] == (i == goal)
            assert abs(meal['food'] - .3 * i) < 1e-6 and not meal['ended']
    kinds = ['ADULT', 'ELIGIBLE', 'MATED', 'SAC', 'GUARDING', 'GUARD_RESTORED', 'HATCHED', 'FAMILY_CARD', 'GENERATION', 'GENERATION_RESTORED']
    indexes = []
    for kind in kinds:
        assert len(values(kind)) == 1, (mode, rules, kind)
        indexes.append(next(i for i, e in enumerate(group) if e['kind'] == kind))
    assert indexes == sorted(indexes)
    for kind in kinds:
        v = values(kind)[0]
        assert v['mode'] == mode and v['rules'] == rules and not v['ended']
    assert values('ADULT')[0]['stage'] == 3 and values('ADULT')[0]['finished_main']
    assert values('ELIGIBLE')[0]['ready_day'] > 0
    assert values('MATED')[0]['mating'] == 'mated'
    sac, guard, restored, hatch = [values(kind)[0] for kind in ['SAC', 'GUARDING', 'GUARD_RESTORED', 'HATCHED']]
    assert sac['mating'] == 'sac' and sac['guard_day'] == 1
    assert guard['mating'] == restored['mating'] == 'guarding' and guard['guard_day'] == restored['guard_day'] == 2
    assert sac['sac_day'] == guard['sac_day'] == restored['sac_day'] == hatch['sac_day']
    assert hatch['mating'] == 'hatched' and hatch['hatch_day'] == sac['sac_day'] + 2
    assert 8 <= hatch['brood'] <= 12 and hatch['generation'] == generation and hatch['phase'] == 'scene'
    assert values('FAMILY_CARD')[0]['phase'] == 'card' and values('FAMILY_CARD')[0]['brood'] == hatch['brood']
    for kind in ['GENERATION', 'GENERATION_RESTORED']:
        v = values(kind)[0]
        assert v['generation'] == generation + 1 and v['stage'] == 0 and v['mating'] == 'none'
        assert not v['can_run'] and not v['can_lock'] and v['phase'] == ''
        assert v['goal'] == 7 and not v['ready']
    young = values('NEXT_MEAL')
    assert len(young) == 3
    for i, meal in enumerate(young, 1):
        assert meal['generation'] == generation + 1 and meal['stage'] == 0 and meal['goal'] == 7
        assert not meal['ready'] and not meal['ended'] and abs(meal['food'] - i * .3) < 1e-6
    assert abs(values('GENERATION_RESTORED')[0]['food'] - .9) < 1e-6
    assert len(values('VISITOR')) >= 1 and len(values('COURT_RESULT')) >= 1
    if mode == 'free':
        card = next(e for e in group if e['kind'] == 'FAMILY_CARD')
        newborn = next(e for e in group if e['kind'] == 'GENERATION')
        ride_elapsed = (datetime.datetime.fromisoformat(newborn['utc']) - datetime.datetime.fromisoformat(card['utc'])).total_seconds()
        assert 12 <= ride_elapsed < 45, 'Follow did not span its ordinary twelve-second ride'
cleanup = rows('CLEANUP')[0]
assert cleanup['active'] == cleanup['gate']['scopes'] == cleanup['gate']['started'] == cleanup['gate']['queued'] == 0
assert cleanup['optionsCreated'] == cleanup['optionsDestroyed']
assert not a.out.exists()
a.out.mkdir(parents=True)
for name in ['manifest.json', 'compile.txt', 'strict.txt']:
    (a.out / name).write_bytes((a.stage / name).read_bytes())
(a.out / 'native-output.txt').write_bytes(('\n'.join(kept) + '\n').encode())
result = dict(passed=True, run=events[0]['run'], source_count=276, ordinary_sources=273,
    source_guards=2, complete_growth_meals=62, completed_moults=9, completed_families=3,
    next_generation_meals=9, adult_refuel_meals=len(rows('ADULT_MEAL')),
    total_meals=62+9+len(rows('ADULT_MEAL')), free_follow_elapsed_seconds=ride_elapsed,
    guarded_restores=3, next_generation_restores=3, events=events,
    model_sha256=m['place_sha256'], original_log=str(a.log), log_sha256=sha(raw),
    creator_errors=errors, creator_warnings=warnings,
    limits='Unbound local Studio/memory. Captures, approaches and player facing scripted; live NPC senses, seeded Normal acceptance/interference and ordinary fixed ticks. Clock acceleration only. Real local rest reconstruction; not natural hunts/traversal, online persistence/rejoin, physical devices or FPS evidence.')
(a.out / 'native.json').write_bytes((json.dumps(result, indent=2) + '\n').encode())
print(json.dumps({k: result[k] for k in ['passed', 'run', 'complete_growth_meals', 'completed_moults', 'completed_families', 'guarded_restores', 'next_generation_restores']}))
