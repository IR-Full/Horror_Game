"""Run native headless checks on Windows, Linux and macOS (Python stdlib only)."""
import os
from pathlib import Path
import platform
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    system = platform.system()
    variants = {
        'Windows': ('win64.exe.zip', 'windows.64', 'Godot_v4.7.2-stable_win64_console.exe'),
        'Linux': ('linux.x86_64.zip', 'linux.64', 'Godot_v4.7.2-stable_linux.x86_64'),
        'Darwin': ('macos.universal.zip', 'macos.universal', 'Godot.app/Contents/MacOS/Godot'),
    }
    slug, target, binary = variants[system]
    cache = Path(os.environ['RUNNER_TEMP']) / 'last-signal-engine'
    cache.mkdir(exist_ok=True)
    archive = cache / 'engine.zip'
    url = f'https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug={slug}&platform={target}'
    urllib.request.urlretrieve(url, archive)
    with zipfile.ZipFile(archive) as package:
        package.extractall(cache)
    engine = cache / binary
    engine.chmod(0o755)
    if system == 'Darwin':
        subprocess.run(['xattr', '-dr', 'com.apple.quarantine', str(cache / 'Godot.app')], check=False)
    os.environ['GODOT_BIN'] = str(engine)
    results = ROOT / 'test-results'
    results.mkdir(exist_ok=True)
    (results / '.gdignore').touch()

    def run(arguments, name, marker=None):
        result = subprocess.run([str(engine), '--headless', '--path', str(ROOT), *arguments],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
        (results / f'ci-{name}.log').write_text(result.stdout, encoding='utf-8')
        print(result.stdout)
        if result.returncode or 'ERROR:' in result.stdout or (marker and marker not in result.stdout):
            raise RuntimeError(f'{name} failed')

    run(['--editor', '--import', '--quit'], 'import')
    for name in ('art', 'sector', 'feature'):
        run(['--', f'--{name}-check'], name, name.upper() + '_PASS')
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2'], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
