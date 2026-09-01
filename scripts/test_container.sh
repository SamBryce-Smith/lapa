#!/usr/bin/env bash
#
# Smoke-test a LAPA container image under both invocation styles.
#
#   usage: scripts/test_container.sh <docker|apptainer> <image-or-sif>
#
# The point of this script is the *entrypoint-less* invocation. Apptainer and
# Singularity translate a Docker ENTRYPOINT into /.singularity.d/runscript,
# which only `apptainer run` uses -- `apptainer exec`, which is what Snakemake's
# `container:` directive emits, bypasses it entirely. `docker run --entrypoint=""`
# is the local stand-in for that, so this script can be run identically on a
# laptop with only Docker and on a cluster with only Apptainer.
#
# This checks that the CLI is *invocable*, not that it is correct; the pytest
# suite covers behaviour and is run before a release.

set -euo pipefail

runtime=${1:-}
image=${2:-}

if [[ "$runtime" != "docker" && "$runtime" != "apptainer" ]] || [[ -z "$image" ]]; then
    echo "usage: $0 <docker|apptainer> <image-or-sif>" >&2
    exit 2
fi

# Console scripts declared under [project.scripts] in pyproject.toml.
entry_points=(
    lapa
    lapa_tss
    lapa_link_tss_to_tes
    lapa_correct_talon_gtf
    lapa_correct_talon
)

failures=0

# Run a command in the container *without* the entrypoint, i.e. the way
# `apptainer exec` (and therefore Snakemake) invokes it.
run_exec() {
    case "$runtime" in
        docker) docker run --rm --entrypoint="" "$image" "$@" ;;
        apptainer) apptainer exec "$image" "$@" ;;
    esac
}

# Run a command through the entrypoint/runscript, to confirm the pre-existing
# behaviour still works.
run_entrypoint() {
    case "$runtime" in
        docker) docker run --rm "$image" "$@" ;;
        apptainer) apptainer run "$image" "$@" ;;
    esac
}

check() {
    local description=$1
    shift
    printf '%-58s' "$description"
    if output=$("$@" 2>&1); then
        echo "ok"
    else
        echo "FAILED"
        echo "$output" | sed 's/^/    /' >&2
        failures=$((failures + 1))
    fi
}

echo "Testing image '$image' with runtime '$runtime'"
echo

# 1. Every console script resolves and runs without the entrypoint. This is the
#    check that fails when the environment is only activated by entrypoint.sh.
for entry_point in "${entry_points[@]}"; do
    check "exec: $entry_point --help" run_exec "$entry_point" --help
done

# 2. The interpreter can import the package. An environment that is on PATH but
#    is otherwise missing activation state surfaces here as an ImportError
#    rather than as a "command not found".
check "exec: python -c 'import lapa'" run_exec python -c "import lapa"

# 3. The entrypoint path still works, unchanged.
check "entrypoint: lapa --help" run_entrypoint lapa --help

echo
if [[ $failures -gt 0 ]]; then
    echo "$failures check(s) failed" >&2
    exit 1
fi
echo "All checks passed"
