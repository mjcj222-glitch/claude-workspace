"""Summarize the controlled replay samples, retaining per-run distributions."""
import gzip
import hashlib
import json
from pathlib import Path
import statistics
import sys

SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/chroma-performance')
PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / 'evidence/quality-performance'
OUTPUT.mkdir(parents=True, exist_ok=True)


def stats(values):
    values = sorted(values)
    if not values:
        return {}
    return {'n': len(values), 'min': values[0], 'median': statistics.median(values),
            'p95': statistics.quantiles(values, n=20, method='inclusive')[18] if len(values) > 1 else values[0],
            'max': values[-1]}


def summarize(ds):
    frames = [f for d in ds for f in d['frames']]
    presses = [r for d in ds for r in d['rows'] if r['kind'] in ['skill', 'clear']]
    clears = [r for d in ds for r in d['timings'] if r['event'] == 'commit_to_ready']
    result = {'board_press_cpu_ms': stats([r['press_cpu_us']/1000 for r in presses]),
              'board_first_draw_ms': stats([r['first_draw_us']/1000 for r in presses]),
              'board_press_over_100ms': sum(r['first_draw_us'] > 100000 for r in presses),
              'ordinary_clear_ms': stats([r['wall_ms'] for r in clears if r['specials'] == 0]),
              'core_clear_ms': stats([r['wall_ms'] for r in clears if r['specials'] > 0]),
              'clear_animation_ms': stats([r['profile']['clear_wall_ms'] for r in clears]),
              'fall_ms': stats([r['profile']['fall_wall_ms'] for r in clears]),
              'physics_cpu_ms': stats([sum(r['profile'][k] for k in ['anchor_us', 'spawn_us', 'solve_us'])/1000 for r in clears]),
              'stages': {}}
    for stage in ['idle', 'clear_held', 'skill_held', 'clear_fx', 'fall']:
        fs = [f for f in frames if f['stage'] == stage]
        wall = []
        for d in ds:
            for previous, current in zip(d['frames'], d['frames'][1:]):
                if previous['stage'] == current['stage'] == stage:
                    wall.append((current['wall_us']-previous['wall_us'])/1000)
        result['stages'][stage] = {'wall_frame_ms': stats(wall),
                                  'render_cpu_ms': stats([f['render_cpu_ms'] for f in fs]),
                                  'llvmpipe_gl_timer_ms': stats([f['render_gpu_ms'] for f in fs]),
                                  'ui_command_cpu_ms': stats([f['cpu'].get('ui_draw_us', 0)/1000 for f in fs]),
                                  'panel_command_cpu_ms': stats([f['cpu'].get('panels_draw_us', 0)/1000 for f in fs]),
                                  'overlay_command_cpu_ms': stats([f['cpu'].get('overlay_draw_us', 0)/1000 for f in fs]),
                                  'process_cpu_ms': stats([f['cpu'].get('process_us', 0)/1000 for f in fs]),
                                  'draw_calls': stats([f['draw_calls'] for f in fs])}
    return result


groups = {}
for label in ['before', 'after', 'fixed']:
    paths = sorted(SOURCE.glob(f'{label}-repeat-*.json'))
    ds = [json.loads(p.read_text()) for p in paths]
    assert len(ds) >= 3, (label, len(ds))
    assert all(not d['errors'] and d['final']['phase'] == 'victory' for d in ds), label
    groups[label] = {'pooled': summarize(ds), 'runs': [{'file': p.name, **summarize([d])} for p, d in zip(paths, ds)]}

reference = json.loads(sorted(SOURCE.glob('before-repeat-*.json'))[0].read_text())
canonical = lambda d: [{k: v for k, v in r.items() if k in ['kind', 'state', 'plan']} for r in d['rows']]
reference_motion = lambda d: [{k: r['profile'][k] for k in ['ticks', 'iterations', 'pending_sim_s', 'last_spawn_sim_s', 'inside_sim_s', 'fall_sim_s'] if k in r['profile']} for r in d['timings'] if r['event'] == 'commit_to_ready']
parity = []
for p in sorted(SOURCE.glob('*-repeat-*.json')):
    d = json.loads(p.read_text())
    parity.append({'file': p.name, 'canonical_rows_equal': canonical(d) == canonical(reference),
                   'physics_tick_profiles_equal': reference_motion(d) == reference_motion(reference),
                   'errors': d['errors']})
assert all(p['canonical_rows_equal'] and p['physics_tick_profiles_equal'] for p in parity), parity

ablation = []
for p in sorted(SOURCE.glob('idle-*.json')):
    d = json.loads(p.read_text())['samples'][1:]
    ablation.append({'file': p.name, 'wall_frame_ms': stats([r['wall_us']/1000 for r in d]),
                     'llvmpipe_gl_timer_ms': stats([r['render_gpu_ms'] for r in d])})

result = {'method': 'Same environment, serial ABBAAB then fixed/control/fixed/fixed; fixed recorded legal inputs. No policy, screenshot or file writes in timed replay; write only after recording stops. Source wrappers and in-memory logging are shared overhead.',
          'limits': ['Frame-aligned programmatic presses do not model OS input arrival.',
                     'Fixed-frame holds have different wall lengths at different FPS; prefer idle/held distributions.',
                     'GL timer values may lag a frame and are software llvmpipe, not device GPU performance.',
                     'Warm-up does not prewarm every future glyph/outline size; rare outliers remain uncertain.',
                     'Engine Performance monitors are coarse sampling; explicit function wrappers and monotonic clocks are the primary CPU/frame measurements.',
                     'Known seed23 refill stall remains separate and unresolved.'],
          'groups': groups, 'canonical_parity': parity, 'idle_ablation': ablation,
          'production_fix_sha256': hashlib.sha256((PROJECT/'scripts/board_skin.gd').read_bytes()).hexdigest()}
(OUTPUT/'comparison.json').write_text(json.dumps(result, indent=2)+'\n')
for p in sorted(SOURCE.glob('*.json')):
    (OUTPUT/(p.name+'.gz')).write_bytes(gzip.compress(p.read_bytes(), mtime=0))
for p in sorted(SOURCE.glob('*.log')):
    (OUTPUT/p.name).write_text(p.read_text())
print(json.dumps({label: groups[label]['pooled'] for label in groups}, indent=2))
