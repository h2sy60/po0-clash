import argparse
import json
import pathlib
import re
import subprocess
import time


def linux_process(pid):
    path = pathlib.Path('/proc') / str(pid)
    values = {}
    for line in (path / 'smaps_rollup').read_text().splitlines():
        if ':' in line:
            key, value = line.split(':', 1)
            if match := re.search(r'(\d+) kB', value):
                values[key] = int(match[1]) * 1024
    return {
        'pid': pid,
        'name': (path / 'comm').read_text().strip(),
        'pss': values['Pss'],
        'rss': values['Rss'],
        'swap_pss': values.get('SwapPss', 0),
    }


def android_processes(args):
    command = [args.adb]
    if args.serial:
        command.extend(['-s', args.serial])
    output = subprocess.check_output(
        command + ['shell', '-n', 'dumpsys', 'meminfo', args.package], text=True,
    )
    reports = re.findall(
        r'\*\* MEMINFO in pid (\d+) \[([^]]+)\] \*\*(.*?)(?=\*\* MEMINFO|\Z)',
        output, re.S,
    )
    values = []
    for pid, name, report in reports:
        pss = re.search(r'TOTAL PSS:\s+(\d+)', report)
        rss = re.search(r'TOTAL RSS:\s+(\d+)', report)
        swap = re.search(r'TOTAL SWAP(?: PSS)? \(KB\):\s+(\d+)', report)
        if pss is None or rss is None:
            raise RuntimeError(f'No complete memory report for {pid}')
        values.append({
            'pid': int(pid), 'name': name,
            'pss': int(pss[1]) * 1024, 'rss': int(rss[1]) * 1024,
            'swap_pss': int(swap[1]) * 1024 if swap else 0,
        })
    if not values:
        raise RuntimeError('The Android application is not running')
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pid', type=int, action='append')
    parser.add_argument('--package')
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial')
    parser.add_argument('--samples', type=int, default=12)
    parser.add_argument('--interval', type=float, default=10)
    parser.add_argument('--settle', type=float, default=30)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    if bool(args.pid) == bool(args.package):
        parser.error('Choose --pid or --package')
    time.sleep(args.settle)
    samples = []
    for index in range(args.samples):
        processes = android_processes(args) if args.package else [
            linux_process(pid) for pid in args.pid
        ]
        sample = {
            'time': time.time(), 'processes': processes,
            **{key: sum(process[key] for process in processes) for key in ('pss', 'rss', 'swap_pss')},
        }
        samples.append(sample)
        args.output.write_text(json.dumps({'samples': samples}, indent=2) + '\n')
        print(json.dumps({key: sample[key] for key in ('time', 'pss', 'rss', 'swap_pss')}), flush=True)
        if index + 1 < args.samples:
            time.sleep(args.interval)


if __name__ == '__main__':
    main()
