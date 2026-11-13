#!/usr/bin/env bash
# The `lint` check: markdownlint-cli2 over every Markdown file (its rules and globs are in .markdownlint-cli2.jsonc),
# then codespell over the repository. yggdrasil.yml runs it from the repository's root in the pinned Node image
# (Debian: it also has the Python 3 codespell runs on), so it runs the same on your own machine:
#   docker run --rm -v "$PWD:/src" -w /src <yggdrasil.yml's lint image> ci/lint.sh
#
# Both tools are pinned. markdownlint-cli2 is run with npx at its exact npm version. codespell's source archive is
# fetched from PyPI, checked against the pinned sha256, and its pure-Python package put on PYTHONPATH (the image has
# Python but no pip). Renovate follows the versions (the comments above them), not the checksum: when it moves
# codespell, copy the sdist's sha256 from https://pypi.org/project/codespell/#files into this file by hand.
set -euo pipefail

# The repository's root, wherever this is run from.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# renovate: datasource=npm depName=markdownlint-cli2
MARKDOWNLINT_CLI2_VERSION=0.24.0
# renovate: datasource=pypi depName=codespell
CODESPELL_VERSION=2.4.3
CODESPELL_SHA256=cbe085e331227b37bb86ef8bddd08dc768c704ee9a07ca869852c093fa2793e2

tools=$(mktemp -d)
trap 'rm -rf "$tools"' EXIT

# Fetches a source archive into $tools and checks it against its pinned sha256: fetch <name> <url> <sha256>.
fetch() {
  curl --fail --silent --show-error --location --retry 3 -o "$tools/$1" "$2"
  if ! echo "$3  $tools/$1" | sha256sum --check --strict --status; then
    echo "ci/lint.sh: $1 does not match its pinned checksum" >&2
    exit 1
  fi
  tar -xzf "$tools/$1" -C "$tools" --no-same-owner
}

echo "== markdownlint-cli2 $MARKDOWNLINT_CLI2_VERSION"
export npm_config_update_notifier=false
npx --yes "markdownlint-cli2@$MARKDOWNLINT_CLI2_VERSION"

echo "== codespell $CODESPELL_VERSION"
fetch codespell.tar.gz \
  "https://files.pythonhosted.org/packages/source/c/codespell/codespell-$CODESPELL_VERSION.tar.gz" "$CODESPELL_SHA256"
PYTHONPATH="$tools/codespell-$CODESPELL_VERSION" PYTHONDONTWRITEBYTECODE=1 python3 -m codespell_lib
