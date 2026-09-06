#!/usr/bin/env bash
set -Eeuo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
source "${TEST_DIR}/test_helper.sh"
mkdir -p "${HOME}/bin"
cat > "${HOME}/bin/brew" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1 $2 $3" == 'bundle install --verbose' ]] || exit 91
if [[ -t 1 ]]; then printf 'STDOUT_TTY=1\n'; else printf 'STDOUT_TTY=0\n'; fi
if [[ -t 2 ]]; then printf 'STDERR_TTY=1\n' >&2; else printf 'STDERR_TTY=0\n' >&2; fi
printf 'NATIVE_STDOUT'
printf '\rDOWNLOAD_STARTED' >&2
# Do not finish until the parent observes streamed output, including an unterminated line.
for attempt in {1..200}; do
    [[ ! -f "${OUTPUT_RELEASE}" ]] || break
    sleep 0.025
done
[[ -f "${OUTPUT_RELEASE}" ]] || exit 92
printf '\nNATIVE_STDOUT_COMPLETE\n'
printf '\nNATIVE_STDERR_COMPLETE\n' >&2
exit "${OUTPUT_EXIT_CODE}"
STUB
chmod +x "${HOME}/bin/brew"

python3 - "${PROJECT_ROOT}" <<'PY'
import errno
import os
import pty
import select
import signal
import subprocess
import sys
import time
from pathlib import Path

root = Path(sys.argv[1])
home = Path(os.environ['HOME'])
script = '''
set -euo pipefail
source "$1/scripts/lib/core.sh"
source "$1/scripts/homebrew.sh"
run_homebrew_step "Fixture installation" bundle install --verbose
'''

for terminal in (False, True):
    for exit_code in (0, 23):
        release = home / f'release-{terminal}-{exit_code}'
        env = dict(os.environ, PATH=f'{home}/bin:/usr/bin:/bin',
                   OUTPUT_RELEASE=str(release), OUTPUT_EXIT_CODE=str(exit_code))
        master = slave = None
        if terminal:
            master, slave = pty.openpty()
        process = subprocess.Popen(
            ['/bin/bash', '-c', script, 'bash', str(root)], env=env,
            stdin=subprocess.DEVNULL,
            stdout=slave if terminal else subprocess.PIPE,
            stderr=slave if terminal else subprocess.PIPE,
            start_new_session=True,
        )
        if terminal:
            os.close(slave)
            streams = {master}
        else:
            streams = {process.stdout.fileno(), process.stderr.fileno()}
        output = b''
        observed_live = False
        deadline = time.monotonic() + 8
        try:
            while streams:
                assert time.monotonic() < deadline, 'Output was buffered or the child stalled'
                readable, _, _ = select.select(list(streams), [], [], 0.1)
                for descriptor in readable:
                    try:
                        data = os.read(descriptor, 65536)
                    except OSError as exc:
                        if terminal and exc.errno == errno.EIO:
                            data = b''
                        else:
                            raise
                    if not data:
                        streams.remove(descriptor)
                        continue
                    output += data
                if (b'DOWNLOAD_STARTED' in output and b'NATIVE_STDOUT' in output
                        and not observed_live):
                    assert process.poll() is None, 'Progress arrived only after the command exited'
                    observed_live = True
                    release.touch()
            assert process.wait(timeout=2) == exit_code, 'Original command status was lost'
            assert observed_live, 'No live progress was observed'
            text = output.decode()
            assert f'STDOUT_TTY={int(terminal)}' in text, 'Standard output TTY was lost'
            assert f'STDERR_TTY={int(terminal)}' in text, 'Standard error TTY was lost'
            assert 'NATIVE_STDOUT_COMPLETE' in text and 'NATIVE_STDERR_COMPLETE' in text
            assert 'Starting: Fixture installation' in text
            if exit_code:
                assert 'Failed: Fixture installation (exit 23, ' in text
                assert 'Finished: Fixture installation' not in text, 'Failed command reported success'
            else:
                assert 'Finished: Fixture installation (' in text and 's)' in text
                assert 'Failed: Fixture installation' not in text
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            if master is not None:
                os.close(master)
            if not terminal:
                process.stdout.close()
                process.stderr.close()
PY
