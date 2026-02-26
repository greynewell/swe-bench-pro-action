FROM python:3.11-slim

# Install Docker CLI (uses host daemon via socket mount), git, jq, curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        jq \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources-docker.list \
    && cp /etc/apt/sources-docker.list /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install mcpbr from feat/swe-bench-pro branch (preflight not yet on PyPI).
# Pinned to commit hash because pip doesn't support branch names with slashes.
# TODO: Replace with `pip install mcpbr` once preflight ships to PyPI.
RUN pip install --no-cache-dir "mcpbr @ git+https://github.com/greynewell/mcpbr.git@136a331232d8a3cb77d26452d1a3cb589d8468d3"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
