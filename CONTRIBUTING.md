# Contributing to Prowlarr Indexers

This guide covers how to contribute to the Prowlarr Indexers repository, including validation processes and schema requirements.

## Prerequisites

> [!IMPORTANT]
> **Python 3.11 or higher** is required - must be installed and accessible via `python3` command

- Git
- Basic understanding of YAML and JSON Schema

## Setup

1. Fork and clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/Indexers.git
cd Indexers
```

2. Set up Python environment:
```bash
# Create virtual environment (recommended)
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Script Commands

### Validation Scripts

#### Quick Validation
```bash
# Validate all indexer definitions (recommended)
./scripts/validate-python.sh
```

#### Python Validation Script
```bash
# Validate all definitions (auto-detects structure)
python3 scripts/validate.py

# Validate specific directory
python3 scripts/validate.py /path/to/definitions

# Validate single file against schema
python3 scripts/validate.py --single file.yml schema.json

# Show only first error (default shows all errors)
python3 scripts/validate.py --first-error-only

# Find best schema version for a file
python3 scripts/validate.py --find-best-version file.yml
```

#### Indexer Sync Script
```bash
# Basic sync from Jackett
./scripts/indexer-sync-v2.sh

# With verbose logging
./scripts/indexer-sync-v2.sh -v

# With debug logging
./scripts/indexer-sync-v2.sh -d

# Automation mode (no prompts)
./scripts/indexer-sync-v2.sh -a

# Skip backporting (recommended for automation)
./scripts/indexer-sync-v2.sh -z

# Push changes to remote
./scripts/indexer-sync-v2.sh -p

# Set remote name
./scripts/indexer-sync-v2.sh -r upstream

# Development mode with pauses
./scripts/indexer-sync-v2.sh -m dev

# Combined: automation mode with push
./scripts/indexer-sync-v2.sh -z -a -p

# See all available options
./scripts/indexer-sync-v2.sh --help
```

## Validation Process

The validation script automatically detects directory structure and validates accordingly:
- **Prowlarr structure**: Uses versioned directories (currently `v11/`) with individual schemas
- **Jackett structure**: Uses flat directory with root `schema.json`

### Schema Versions

Each Cardigann version has its own schema in `definitions/v{VERSION}/schema.json`. Current active version is:

- **v11** - Active version with all indexer definitions (522+ indexers) including:
  - Predefined setting type: `info_category_8000`
  - Optional `selectorinputs` and `getselectorinputs` for login section
  - Extended language support and enhanced SelectorBlock validation

> [!WARNING]
> **v10** - DEPRECATED as of 2025-08-24
> - All indexers migrated to v11
> - Schema remains for historical reference only

> [!NOTE]
> For historical version information and deprecated schemas (v1-v9), see the main [README.md](README.md).

### Validation Requirements

#### YAML Format Requirements
- All keys must be strings (no unquoted boolean or numeric keys)
- Boolean values in `options` and `case` fields are automatically converted to strings
- Numeric keys are automatically converted to strings during validation

#### Common Issues and Solutions

> [!WARNING]
> **Boolean Keys/Values**
```yaml
# ❌ Problematic
options:
  true: yes    # boolean key 'true'
  false: no    # boolean key 'false'

# ✅ Preferred (quotes ensure string keys)
options:
  "true": yes
  "false": no
```

> [!WARNING]
> **Numeric Keys**

```yaml
# ❌ Problematic
options:
  1: "Option 1"    # numeric key
  2: "Option 2"

# ✅ Preferred
options:
  "1": "Option 1"
  "2": "Option 2"
```

### Validation Quirks and Limitations

#### Automatic Type Conversion

The Python validation system automatically handles common YAML parsing issues:

1. **Boolean Keys**: `True`/`False` keys are converted to `"true"`/`"false"`
2. **Numeric Keys**: Integer keys are converted to string representations
3. **Boolean Values in Options**: Boolean values in `options` and `case` fields are converted to lowercase strings

#### Schema Strictness

The JSON Schema validation is strict about types:
- All dictionary keys must be strings
- Values must match the expected type exactly
- Pattern properties are enforced with regex matching

#### YAML vs JSON Differences

YAML parsing can introduce type conversions that don't occur in JSON:
- Unquoted `true`/`false` become booleans
- Unquoted numbers become integers/floats
- Date-like strings may be parsed as datetime objects

## Testing Your Changes

### Local Testing
```bash
# Test all definitions (supports both Prowlarr and Jackett structures)
./scripts/validate-python.sh

# Test specific directory (current versions)
python3 scripts/validate.py definitions/v11
python3 scripts/validate.py definitions/v10

# Test external projects (like Jackett)
python3 scripts/validate.py ../jackett/src/Jackett.Common/Definitions

# Test single file
python3 scripts/validate.py --single yourindexer.yml schema.json

# Show all errors for comprehensive debugging
python3 scripts/validate.py  # default behavior

# Show only first error for quick fixes
python3 scripts/validate.py --first-error-only
```

### CI/CD Workflows

The repository uses several automated workflows to ensure code quality:

#### 1. YAML Validation (`ci.yml`)
- **Triggers**: Push/PR to `master` on YAML files in `definitions/`
- **Purpose**: Validates YAML syntax and formatting
- **Tools**: `yamllint` with GitHub annotations
- **Runs**: On every change to definition files

#### 2. Python Validation (`python-validation.yml`) 
- **Triggers**: Push/PR to `master` on Python files in `scripts/` or `requirements.txt`
- **Purpose**: Validates Python script syntax and functionality
- **Tools**: `py_compile` syntax checking
- **Runs**: On script changes only

#### 3. Schema Validation (part of `ci.yml`)
- **Purpose**: Validates all indexer definitions against JSON schemas
- **Tool**: Python-based validation using `scripts/validate.py`
- **Coverage**: All definition files in versioned directories

#### 4. Indexer Sync Automation (`indexer-sync.yml`)
- **Schedule**: 3 times daily (2 AM, 10 AM, 6 PM UTC)
- **Purpose**: Automatically syncs indexers from Jackett repository
- **Features**: 
  - Automated PR creation for updates
  - Manual trigger with debug options
  - Caching for performance (Python deps + Jackett data)
- **Output**: Creates/updates `automated-indexer-sync` branch

#### 5. Label Actions (`label-actions.yml`)
- **Triggers**: Label changes on issues/PRs
- **Purpose**: Automated issue/PR management based on labels

All workflows include:
- Concurrency controls to prevent duplicate runs
- Proper caching for dependencies
- GitHub status checks integration

## Indexer Sync Process

Indexers are primarily synced from [Jackett](https://github.com/Jackett/Jackett). There is an automated branch - `automated-indexer-sync` updated via GitHub Actions that run 3 times daily (12 AM, 8 AM, 4 PM UTC). However, this must be manually merged to `master`.

### Community Sync Options

We sync indexer definitions from [Jackett](https://github.com/Jackett/Jackett). The community can help with updates using either approach:

**Option 1: PR the Automated Sync Branch**
1. Monitor automated updates: [View Latest Sync](https://github.com/Prowlarr/Indexers/compare/master...automated-indexer-sync)
2. Fork the Repo and Create a PR from your fork's `automated-indexer-sync` branch to upstream's `master`

**Option 2: Run Sync Script Manually**
1. Fork this repository and clone it
2. Use the sync script `scripts/indexer-sync-v2.sh` with available options:

   | Flag | Env Variable | Description |
   |------|-------------|-------------|
   | `-a` | | Automation mode - runs without interactive prompts |
   | `-b BRANCH` | | Target branch to sync to (default: master) |
   | `-c TEMPLATE` | | Custom commit message template |
   | `-d` | `DEBUG=true` | Enable DEBUG logging - shows detailed execution traces |
   | `-f` | | Force push with lease - overwrites remote branch safely |
   | `-j URL` | | Jackett repository URL to sync from |
   | `-J BRANCH` | | Jackett branch to sync from (default: master) |
   | `-m MODE` | | Execution mode: `normal` (default), `development`, `jackett` |
   | `-n NAME` | | Jackett remote name in git |
   | `-o REMOTE` | | Remote to push changes to (default: origin) |
   | `-p` | | Enable push mode - automatically pushes changes |
   | `-r REMOTE` | | Prowlarr remote name (default: origin) |
   | `-R BRANCH` | | Prowlarr release branch (default: master) |
   | `-u URL` | | Prowlarr repository URL |
   | `-v` | `VERBOSE=true` | Enable VERBOSE logging - shows detailed progress info |
   | `-z` | | Skip backport - faster sync, skips older version updates |
3. Create PR to `master` with your sync results

### Quick Start

1. Fork this repository on GitHub
1. Clone your fork
    ```bash
    git clone https://github.com/YOUR_USERNAME/Indexers.git
    cd Indexers
    ```
1. Install dependencies
    ```bash
    # Create virtual environment (recommended)
    python -m venv .venv
    
    # Activate virtual environment
    # On Linux/Mac:
    source .venv/bin/activate
    # On Windows:
    source .venv/Scripts/activate
    
    # Install Python dependencies
    pip install -r requirements.txt
    ```
1. Execute sync script
    ```bash
    chmod +x scripts/indexer-sync-v2.sh
    ./scripts/indexer-sync-v2.sh -r upstream -p
    ```

### Sync Script Features

The indexer sync script includes several performance and usability improvements:

- **Sparse Checkout**: Automatically configures git sparse checkout to only download Jackett indexer definitions (`src/Jackett.Common/Definitions/*`), significantly reducing bandwidth and disk usage
- **Controlled Logging**: Three logging levels for better troubleshooting:
  - Default: Clean output (INFO, WARN, ERROR only)
  - `-v` or `VERBOSE=true`: Shows detailed parameter and operation information
  - `-d` or `DEBUG=true`: Shows all logging including debug traces
- **Efficient Syncing**: Only fetches the necessary files from the large Jackett repository
- **Blocklist Support**: Excludes problematic indexers via `scripts/blocklist.txt` (no hardcoded defaults)

### Automated Sync Details
- **Schedule**: 3 times daily (2 AM, 10 AM, 6 PM UTC) via GitHub Actions
- **Manual Trigger**: Available through GitHub Actions workflow dispatch
- **Mode**: Uses `-z` flag (skips backporting) for automated runs
- **Pull Requests**: Automatically creates/updates PRs with sync results
- **Caching**: Separate caches for Python dependencies and Jackett data for faster runs

## Submitting Changes

1. Create a feature branch:
```bash
git checkout -b feature/new-indexer
```

2. Make your changes and validate:
```bash
./scripts/validate-python.sh
```

3. Commit with conventional format:
```bash
git commit -m "feat: add new indexer xyz"
git commit -m "fix: update indexer abc schema"
git commit -m "docs: improve contributing guide"
```

4. Push and create pull request:
```bash
git push origin feature/new-indexer
```

## Schema Development

### Adding New Fields

When adding fields to schemas:
1. Update the appropriate `definitions/v{VERSION}/schema.json` (currently v11)
2. Test against existing indexer definitions
3. Consider backward compatibility

### Version Management

- New breaking changes require a new schema version (v12+)
- Current active version (v11) should remain stable
- Deprecated versions (v1-v9) are frozen and no longer updated
- Test schema changes against the full definition set

## Troubleshooting

### Common Validation Errors

**"expected string or bytes-like object, got 'int'"**
- Usually caused by numeric keys in dictionaries
- Fixed automatically by the validation system

**"True is not of type 'string'"**
- Boolean value where string expected
- Check `options` and `case` field values

**"pattern does not match"**
- Field doesn't match required regex pattern
- Check schema requirements for the specific field

### Getting Help

> [!TIP]
> Need assistance? Here are your best resources:
> - Check existing issues: https://github.com/Prowlarr/Indexers/issues
> - Review schema documentation: https://wiki.servarr.com/prowlarr/cardigann-yml-definition
> - Ask on Discord: https://requests.prowlarr.com/

## Best Practices

> [!TIP]
> Follow these guidelines for successful contributions:
> 1. Always validate before submitting
> 2. Use descriptive commit messages
> 3. Test changes thoroughly
> 4. Follow existing patterns in similar indexers
> 5. Quote YAML keys that might be interpreted as booleans/numbers
> 6. Keep indexer definitions focused and minimal
