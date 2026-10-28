"""Real headless ENet processes, separate writable user-data directories."""
import argparse
import os
import shutil
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot4') or shutil.which('godot'))
    parser.add_argument('--players', type=int, choices=(2, 3, 4), default=2)
    parser.add_argument('--port', type=int, default=27941)
    parser.add_argument('--verbose', action='store_true')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Set GODOT_BIN or pass --godot /path/to/Godot 4.7.2')
    root = Path(__file__).resolve().parents[1]
    output = root / 'test-results' / f'lan-{args.players}'
    output.mkdir(parents=True, exist_ok=True)
    jobs = []
    try:
        for index in range(args.players):
            mode = 'host' if index == 0 else 'client'
            runtime = output / f'runtime-{index}'
            runtime.mkdir(exist_ok=True)
            env = os.environ.copy()
            env['APPDATA'] = str(runtime)
            env['LOCALAPPDATA'] = str(runtime)
            env['XDG_DATA_HOME'] = str(runtime)
            env['XDG_CONFIG_HOME'] = str(runtime)
            path = output / f'{mode}-{index}.log'
            log = path.open('w', encoding='utf-8')
            command = [args.godot, '--headless', '--path', str(root), '--',
                       f'--test={mode}', f'--players={args.players}', f'--port={args.port}',
                       f'--test-user-dir={runtime}']
            if args.verbose:
                command.insert(1, '--verbose')
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
            jobs.append((process, log, path))
            time.sleep(0.6)
        deadline = time.monotonic() + 80
        while any(proc.poll() is None for proc, _, _ in jobs):
            if time.monotonic() > deadline:
                raise TimeoutError('LAN smoke test exceeded 80 seconds')
            if any(proc.poll() not in (None, 0) for proc, _, _ in jobs):
                raise RuntimeError('A Godot process failed')
            time.sleep(0.25)
    except (TimeoutError, RuntimeError, OSError) as error:
        print(error)
        return 1
    finally:
        for proc, log, _ in jobs:
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=10)
            log.close()
    good = True
    for proc, _, path in jobs:
        content = path.read_text(encoding='utf-8', errors='replace')
        errors = [line for line in content.splitlines() if 'ERROR:' in line or 'TEST_FAIL' in line]
        passed = proc.returncode == 0 and 'TEST_PASS' in content and not errors
        good &= passed
        print(f'{path.name}: {"PASS" if passed else "FAIL"}')
        print('\n'.join(content.splitlines()[-12:]))
    return 0 if good else 1


if __name__ == '__main__':
    sys.exit(main())
