# Multi-stage build: resolve/install the pixi-locked "default" (non-editable,
# production) environment in a build stage that has pixi available, then copy
# only the resulting environment into a minimal runtime image.

# pixi.lock only declares linux-64 (x86_64); pin the build platform so
# `pixi install --locked` matches it regardless of host architecture (e.g.
# Apple Silicon). Declared as an ARG (default linux/amd64) rather than a
# literal so `docker build --build-arg PIXI_PLATFORM=...` can still override
# it, and so Docker's linter doesn't flag a hardcoded --platform constant.
ARG PIXI_PLATFORM=linux/amd64

FROM --platform=$PIXI_PLATFORM ghcr.io/prefix-dev/pixi:0.77.1-jammy AS build

WORKDIR /app

# Copy just what's needed to install the locked "default" environment: pixi's
# manifest/lockfile, plus the source tree required to build the local,
# non-editable "lapa" pypi-dependency (pyproject.toml references README.md).
COPY pyproject.toml pixi.lock README.md /app/
COPY lapa/ /app/lapa/

# --locked fails the build instead of silently re-solving if pixi.lock is out
# of sync with pyproject.toml.
RUN pixi install --locked -e default

# Generate an entrypoint that activates the pixi environment, then execs the
# container command, so the runtime image doesn't need pixi installed at all.
RUN printf '#!/bin/sh\n%s\nexec "$@"' "$(pixi shell-hook -e default)" > /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# Barebones runtime image: no pixi binary, build cache, or build tooling.
FROM --platform=$PIXI_PLATFORM ubuntu:22.04 AS production

WORKDIR /app
COPY --from=build /app/.pixi/envs/default /app/.pixi/envs/default
COPY --from=build /app/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Verify installation
RUN ["/entrypoint.sh", "lapa", "--help"]

# Default command
CMD ["lapa", "--help"]
