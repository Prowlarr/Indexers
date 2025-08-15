# Contributing to Prowlarr Indexers

This guide covers how to contribute to the Prowlarr Indexers repository, including validation processes and schema requirements.

## Prerequisites

- Python 3.11 or higher
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

## Validation Process

### Quick Validation

To validate all indexer definitions:
```bash
./scripts/validate-python.sh
```

The validation script automatically detects directory structure and validates accordingly:
- **Prowlarr structure**: Uses versioned directories (`v10/`, `v11/`) with individual schemas
- **Jackett structure**: Uses flat directory with root `schema.json`

### Validation Commands

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

### Schema Versions

Each Cardigann version has its own schema in `definitions/v{VERSION}/schema.json`. Active versions are:
- **v11** - Latest version with newest features
- **v10** - Current stable version

### Validation Requirements

#### YAML Format Requirements
- All keys must be strings (no unquoted boolean or numeric keys)
- Boolean values in `options` and `case` fields are automatically converted to strings
- Numeric keys are automatically converted to strings during validation

#### Common Issues and Solutions

**Boolean Keys/Values**
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

**Numeric Keys**
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

# Test specific directory
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

### CI Testing

All pull requests are automatically tested with:
- YAML lint validation (`yamllint`)
- JSON Schema validation (Python-based)

## Indexer Sync Process

Indexers are primarily synced from [Jackett](https://github.com/Jackett/Jackett) automatically via GitHub Actions that run daily at 2 AM UTC. The sync can also be triggered manually through the GitHub Actions interface or by running the sync script locally:

```bash
# Manual sync (with automation mode)
./scripts/indexer-sync-v2.sh -z -a -p

# Development mode sync
./scripts/indexer-sync-v2.sh -z -m dev
```

### Automated Sync Details
- **Schedule**: Daily at 2 AM UTC via GitHub Actions
- **Manual Trigger**: Available through GitHub Actions workflow dispatch
- **Mode**: Uses `-z` flag (skips backporting) for automated runs
- **Pull Requests**: Automatically creates/updates PRs with sync results

### Manual Sync Options
- `-z` - Skip backporting (recommended for automation)
- `-a` - Automation mode (skip interactive prompts)
- `-p` - Push changes to remote
- `-m dev` - Development mode with pauses for review

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
1. Update the appropriate `definitions/v{VERSION}/schema.json`
2. Test against existing indexer definitions
3. Consider backward compatibility

### Version Management

- New breaking changes require a new schema version
- Existing versions should remain frozen
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

- Check existing issues: https://github.com/Prowlarr/Indexers/issues
- Review schema documentation: https://wiki.servarr.com/prowlarr/cardigann-yml-definition
- Ask on Discord: https://requests.prowlarr.com/

## Best Practices

1. Always validate before submitting
2. Use descriptive commit messages
3. Test changes thoroughly
4. Follow existing patterns in similar indexers
5. Quote YAML keys that might be interpreted as booleans/numbers
6. Keep indexer definitions focused and minimal