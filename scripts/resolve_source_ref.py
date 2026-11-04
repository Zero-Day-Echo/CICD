"""Resolve an optional immutable business source from an annotated release tag."""
import argparse
import os
from pathlib import Path
import re
import subprocess


def source_ref(repository, tag, fallback='main'):
    record = subprocess.check_output(['git', '-C', str(repository), 'for-each-ref',
        '--format=%(objecttype)%00%(contents)', 'refs/tags/' + tag], text=True)
    kind, _, message = record.partition('\0')
    if kind != 'tag': return fallback
    for line in message.splitlines():
        if line.startswith('source-ref:'):
            ref = line.partition(':')[2].strip()
            if not re.fullmatch(r'[0-9a-fA-F]{40}', ref):
                raise ValueError('source-ref must identify a full source commit SHA')
            return ref
    return fallback


def pushed_source_ref(repository, tag, fallback='main'):
    # checkout@v4 may fetch a tag's peeled commit directly into refs/tags/*.
    # Fetch the actual tag object before reading its annotation.
    subprocess.run(['git', '-C', str(repository), 'fetch', '--force', '--no-tags',
                    'origin', f'refs/tags/{tag}:refs/tags/{tag}'], check=True)
    return source_ref(repository, tag, fallback)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    args = parser.parse_args()
    ref = os.environ.get('CHECKOUT_REF', 'main')
    if os.environ.get('GITHUB_EVENT_NAME') == 'push':
        ref = pushed_source_ref(args.repository, os.environ['RELEASE_TAG'], ref)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write('checkout_ref=' + ref + '\n')
    with open(os.environ['GITHUB_ENV'], 'a') as environment:
        environment.write('CHECKOUT_REF=' + ref + '\n')
    print('Business source checkout: ' + ref)


if __name__ == '__main__': main()
