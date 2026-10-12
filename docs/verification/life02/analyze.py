"""Summarize check_laptop.gd CSV: python analyze.py path/to/life02_frames.csv."""
import csv
import json
import math
import sys
from pathlib import Path

NAMES = ['morning_orbit', 'morning_eye', 'midday_orbit', 'midday_eye',
         'dusk_orbit', 'dusk_eye', 'night_orbit', 'night_eye']
rows = list(csv.DictReader(Path(sys.argv[1]).open(encoding='utf-8')))

def percentile(values, p):
    values = sorted(values)
    return round(values[max(0, math.ceil(len(values) * p) - 1)], 3)

def summarize(items):
    frame = [float(r['frame_ms']) for r in items]
    result = dict(frames=len(frame), mean_ms=round(sum(frame)/len(frame), 3),
                  p95_ms=percentile(frame, .95), p99_ms=percentile(frame, .99),
                  max_ms=max(frame), over_33_3ms=sum(x > 33.3 for x in frame),
                  over_50ms=sum(x > 50 for x in frame))
    for key in ['process_ms', 'physics_ms', 'render_cpu_ms', 'render_gpu_ms']:
        result[key+'_p95'] = percentile([float(r[key]) for r in items], .95)
    result['hour_start_end'] = [float(items[0]['hour']), float(items[-1]['hour'])]
    result['sun_x_start_end'] = [float(items[0]['sun_x']), float(items[-1]['sun_x'])]
    return result

print(json.dumps({'all': summarize(rows), 'phases': {
    name: summarize([r for r in rows if int(r['phase']) == phase])
    for phase, name in enumerate(NAMES)}}, indent=2))
