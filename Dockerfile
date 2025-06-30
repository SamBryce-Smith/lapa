# Alternative: Start with Python 3.7 and install uv
# use full version instead of slim to ensure gcc compiler installed (bamread dependency)
FROM python:3.7.17-bookworm

# Copy uv binary from official image (pinned to specific version for reproducibility)
COPY --from=ghcr.io/astral-sh/uv:0.7.17 /uv /uvx /bin/

# Set environment variables for uv
ENV UV_SYSTEM_PYTHON=1
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# Set working directory
WORKDIR /app

# Copy minimal package files
COPY README.md setup.py /app/
COPY lapa/ /app/lapa/

# Install the package using uv with cache mount (+ certain dependencies first to avoid uv resolving max compatible version and returning errors)
# Install pyranges 0.0.120 to avoid "pandas.errors.IntCastingNaNError: Cannot convert non-finite values (NA or inf) to integer" error with 
# suspect introduced in 0.0.121 (https://github.com/pyranges/pyranges/blob/c981927c7721073e96ceb85192ceafd36173d4a8/CHANGELOG.txt#L53)
# https://github.com/mortazavilab/lapa/issues/30
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system "pyrle<0.0.41" "pyranges==0.0.120" && \
    uv pip install --system .

# Verify installation
RUN lapa --help

# Default command
CMD ["lapa", "--help"]