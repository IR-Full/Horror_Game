"""Run native headless checks on Windows, Linux and macOS (Python stdlib only)."""
import os
import hashlib
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
        'Windows': ('win64.exe.zip', '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953', 'Godot_v4.7.2-stable_win64_console.exe'),
        'Linux': ('linux.x86_64.zip', 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4', 'Godot_v4.7.2-stable_linux.x86_64'),
        'Darwin': ('macos.universal.zip', 'c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e', 'Godot.app/Contents/MacOS/Godot'),
    }
    slug, digest, binary = variants[system]
    cache = Path(os.environ['RUNNER_TEMP']) / 'last-signal-engine'
    cache.mkdir(exist_ok=True)
    archive = cache / 'engine.zip'
    # Official release mirror avoids the download router's datacenter HTTP 403.
    url = f'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_{slug}'
    request = urllib.request.Request(url, headers={'User-Agent': 'LastSignal-CI/0.6'})
    with urllib.request.urlopen(request, timeout=120) as response, archive.open('wb') as output:
        import shutil
        shutil.copyfileobj(response, output)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
        raise RuntimeError('Godot release archive checksum mismatch')
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
    for name in ('art', 'sector', 'feature', 'update', 'voice', 'expansion', 'depot', 'hospital', 'horror', 'props', 'map-finish', 'random'):
        run(['--', f'--{name}-check'], name, name.upper().replace('-', '_') + '_PASS')
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--voice', '--port', '27955'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--depot', '--port', '27973'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--voice', '--map-id', '1', '--port', '27975'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--hospital', '--port', '27983'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--voice', '--map-id', '2', '--port', '27985'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--horror', '--port', '27993'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/run_smoke.py', '--players', '2', '--random', '--port', '28003'], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
