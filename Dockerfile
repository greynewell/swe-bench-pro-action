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
RUN pip install --no-cache-dir "mcpbr @ git+https://github.com/supermodeltools/mcpbr.git@9bd51138e201e19fcf8e7b6b2f4be6f3e7b55c1f"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
