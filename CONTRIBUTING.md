# Contributing

## Development Setup

1. Clone the repo:

```bash
git clone https://github.com/greynewell/swe-bench-pro-action.git
cd swe-bench-pro-action
```

2. Build the Docker image:

```bash
docker build -t swe-bench-pro-action .
```

3. Verify the build:

```bash
docker run --rm --entrypoint="" swe-bench-pro-action mcpbr --version
```

## Testing Locally

Run a preflight check against a single Python instance:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e GITHUB_WORKSPACE="$(pwd)" \
  swe-bench-pro-action \
  preflight swe-bench-pro 1 "" python 2 600 false "" "" "" json ""
```

Arguments are positional and map to the inputs defined in `action.yml`:

```
MODE BENCHMARK SAMPLE_SIZE TASK_IDS FILTER_CATEGORY MAX_CONCURRENT TIMEOUT FAIL_FAST CONFIG ANTHROPIC_API_KEY MODEL OUTPUT_FORMAT MCPBR_VERSION
```

## Project Structure

```
├── action.yml          # GitHub Action definition (inputs, outputs, branding)
├── Dockerfile          # Container image with mcpbr + Docker CLI
├── entrypoint.sh       # Main script: builds and runs mcpbr commands
├── .github/workflows/
│   ├── test.yml            # CI: Docker build + single-instance smoke test
│   └── full-preflight.yml  # Manual: full preflight across all 4 languages
```

## How It Works

The action runs as a Docker container on the GitHub Actions runner. It uses the host's Docker daemon (via socket mount) to create **sibling containers** for each SWE-bench instance:

1. `entrypoint.sh` receives inputs as positional args from `action.yml`
2. It builds a `mcpbr preflight` or `mcpbr run` command based on the mode
3. mcpbr pulls SWE-bench Docker images and runs tests in isolated containers
4. Results are parsed and set as GitHub Actions outputs + job summary

## Submitting Changes

1. Fork the repo and create a branch
2. Make your changes
3. Ensure `docker build` succeeds
4. Test locally with the command above
5. Open a PR against `main`

## mcpbr Dependency

The Dockerfile currently installs mcpbr from a specific git commit (the `feat/swe-bench-pro` branch) because the preflight command hasn't been published to PyPI yet. Once it's released, the install will switch to `pip install mcpbr`.

If you need to update the pinned commit:

```dockerfile
RUN pip install --no-cache-dir "mcpbr @ git+https://github.com/greynewell/mcpbr.git@<NEW_COMMIT_HASH>"
```
