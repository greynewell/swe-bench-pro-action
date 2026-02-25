# SWE-bench Pro Evaluation Action

A GitHub Action for running [SWE-bench Pro](https://github.com/greynewell/mcpbr) preflight validation and agent evaluation, powered by [mcpbr](https://pypi.org/project/mcpbr/).

This is the first SWE-bench evaluation action available on the GitHub Marketplace.

## Quick Start

### Preflight Validation

Validate that golden patches pass all tests before running agent evaluations:

```yaml
- uses: greynewell/swe-bench-pro-action@v1
  with:
    mode: preflight
    sample-size: "5"
```

### Full Evaluation

Run your MCP agent against SWE-bench Pro instances:

```yaml
- uses: greynewell/swe-bench-pro-action@v1
  with:
    mode: evaluate
    config: mcpbr.yaml
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
    sample-size: "10"
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `mode` | `preflight` | `preflight` (validate golden patches) or `evaluate` (run agent) |
| `benchmark` | `swe-bench-pro` | Benchmark name |
| `sample-size` | *(all)* | Number of instances to evaluate |
| `task-ids` | *(empty)* | Comma-separated instance IDs |
| `filter-category` | *(empty)* | Filter by language or repo substring |
| `max-concurrent` | `2` | Max concurrent Docker containers |
| `timeout` | `300` | Per-test timeout in seconds |
| `fail-fast` | `false` | Stop on first failure |
| `config` | *(empty)* | Path to mcpbr YAML config (required for evaluate) |
| `anthropic-api-key` | *(empty)* | Anthropic API key (evaluate mode) |
| `model` | *(empty)* | Model override |
| `output-format` | `json,junit` | Comma-separated: `json`, `junit`, `markdown`, `html` |
| `mcpbr-version` | *(latest)* | Pin a specific mcpbr version |

## Outputs

| Output | Description |
|--------|-------------|
| `results-path` | Path to the results directory |
| `total` | Total instances evaluated |
| `passed` | Number passed |
| `failed` | Number failed |
| `success-rate` | Success rate percentage |

## Examples

### CI Preflight Check

Run preflight on every push to catch environment issues early:

```yaml
name: SWE-bench Preflight
on: [push, pull_request]

jobs:
  preflight:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Free disk space
        uses: jlumbroso/free-disk-space@main
        with:
          tool-cache: false

      - name: Run SWE-bench preflight
        uses: greynewell/swe-bench-pro-action@v1
        with:
          mode: preflight
          sample-size: "3"
          fail-fast: "true"
```

### Nightly Evaluation

Run a full evaluation on a schedule:

```yaml
name: SWE-bench Evaluation
on:
  schedule:
    - cron: "0 2 * * *"  # 2 AM UTC daily

jobs:
  evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Free disk space
        uses: jlumbroso/free-disk-space@main
        with:
          tool-cache: false

      - name: Run evaluation
        id: eval
        uses: greynewell/swe-bench-pro-action@v1
        with:
          mode: evaluate
          config: mcpbr.yaml
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          sample-size: "20"
          max-concurrent: "4"
          output-format: "json,junit,markdown"

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: swe-bench-results
          path: ${{ steps.eval.outputs.results-path }}

      - name: Check success rate
        run: |
          echo "Success rate: ${{ steps.eval.outputs.success-rate }}%"
          echo "Passed: ${{ steps.eval.outputs.passed }}/${{ steps.eval.outputs.total }}"
```

### Filter by Language

Evaluate only Python instances:

```yaml
- uses: greynewell/swe-bench-pro-action@v1
  with:
    mode: preflight
    filter-category: python
    sample-size: "10"
```

### Specific Task IDs

Run specific instances:

```yaml
- uses: greynewell/swe-bench-pro-action@v1
  with:
    mode: preflight
    task-ids: "django__django-16046, scikit-learn__scikit-learn-25638"
```

## Disk Space

SWE-bench Docker images are large. On GitHub-hosted runners, use [jlumbroso/free-disk-space](https://github.com/jlumbroso/free-disk-space) to reclaim ~30GB:

```yaml
- uses: jlumbroso/free-disk-space@main
  with:
    tool-cache: false    # keep tool cache for faster builds
```

## Concurrency Guidance

| Runner Type | Recommended `max-concurrent` | Notes |
|-------------|------------------------------|-------|
| Free (ubuntu-latest) | 2 | 2 vCPU, 7 GB RAM |
| Standard (4-core) | 4 | 4 vCPU, 16 GB RAM |
| Large (8-core) | 6-8 | 8 vCPU, 32 GB RAM |

## Architecture

This action runs as a Docker container on the GitHub Actions runner. It uses the host's Docker daemon (via socket mount) to create sibling containers for SWE-bench instances:

```
GitHub Runner (ubuntu-latest, x86_64)
├── Docker Daemon (native)
├── Action Container (mcpbr + Docker CLI)
│   └── /var/run/docker.sock (auto-mounted)
├── SWE-bench Container 1 (sibling)
└── SWE-bench Container 2 (sibling)
```

Running on x86_64 runners avoids ARM64/QEMU compatibility issues with Go, JavaScript, and TypeScript SWE-bench Pro instances.

## License

MIT
