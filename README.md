# Indexers

[![Supported Indexers](https://img.shields.io/badge/Supported%20Indexers-View%20all%20currently%20supported%20indexers%20%26%20trackers-important)](https://wiki.servarr.com/en/prowlarr/supported-indexers)

This Repo contains Cardigann YML indexer definitions for [Prowlarr](https://github.com/Prowlarr/Prowlarr).

For more information on the formatting of the YML Indexer Definition, please see [our Prowlarr Cardigann YML Version / Definition wiki entry](https://wiki.servarr.com/en/prowlarr/cardigann-yml-definition)

To develop and test definitions, you may use the [Custom Definition Folder](https://wiki.servarr.com/prowlarr/indexers#adding-a-custom-yml-definition)

For Prowlarr Indexer Requests; please see [our request forum on Discord](https://requests.prowlarr.com/)

## Definitions from Jackett

With [some differences](https://github.com/Prowlarr/Indexers/issues/370) and a few exceptions Prowlarr Cardigann Indexers are synced upstream with [Jackett](https://github.com/Jackett/Jackett) via the [indexer-sync script in this repository](https://github.com/Prowlarr/Indexers/blob/master/scripts/indexer-sync-v2.sh). Syncs are automated daily via GitHub Actions, but can also be triggered manually. Any user may also [pull request](https://github.com/Prowlarr/Indexers/compare) a manual sync.

### Sync Jackett Indexers

#### Quick Start


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

1. Create pull request using the output link to create a PR from your fork to this repository

## Definition Versions

Versions require Prowlarr Cardigann C# modifications.
Prowlarr will fall back to a previous version if no YML exists for the current version.

## Schemas

Each Cardigann Version has a YML Schema for it contained within the definitions's respective folder named `schema.json`
For more specific details between versions the schema files can be compared.

To test a definition file against a specific schema use the command below.

### Python Validation

```bash
# Setup (one time)
python -m venv .venv

# Activate virtual environment
# On Linux/Mac:
source .venv/bin/activate
# On Windows:
source .venv/Scripts/activate

pip install -r requirements.txt

# Validate all definitions (supports both Prowlarr versioned and Jackett flat structures)
python scripts/validate.py

# Validate specific directory
python scripts/validate.py /path/to/definitions

# Validate single file against schema
python scripts/validate.py --single "file.yml" "schema.json"

# Show only first error (default shows all errors)
python scripts/validate.py --first-error-only

# Find best schema version for a file
python scripts/validate.py --find-best-version "file.yml"

# Or use convenience script
./scripts/validate-python.sh
```

The validation script supports:
- **Flexible directory structures**: Works with Prowlarr's versioned directories (`v10/`, `v11/`) and Jackett's flat structure with root `schema.json`
- **All errors by default**: Shows all validation issues at once instead of stopping at the first error
- **Concise error messages**: Clean output showing only validation type, schema path, and invalid values
- **Auto-detection**: Automatically detects directory structure and uses appropriate validation method

## Active Versions

The repository currently supports indexer definition schemas from v1 through v11. The latest available versions are:

- **V11 Indexers** - [Dev 1.20.0.4590](https://github.com/Prowlarr/Prowlarr/releases/tag/v1.20.0.4590)
  - Prowlarr Cardigann v11 includes several changes such as:
    - Predefined setting type: `info_category_8000`
    - Optional `selectorinputs` and `getselectorinputs` for login section
    - Extended language support with duplicated language codes
    - Enhanced SelectorBlock validation with dependency rules

- **V10 Indexers** - [Dev 1.18.0.4543](https://github.com/Prowlarr/Prowlarr/releases/tag/v1.18.0.4543)
  - Prowlarr Cardigann v10 includes several changes such as:
    - Predefined settings type: `info_cookie`, `info_flaresolverr` and `info_useragent`
    - Enhanced login validation with conditional requirements
    - Extended SelectorBlock functionality with type restrictions

## Deprecated Versions

### V1 Indexers - Legacy Beta

- Prowlarr Cardigann v1 are base level standard YML
- No new indexers are to be added to v1 as of 2021-10-13
- No new updates backported to v1 as of 2021-10-17

### V2 Indexers - Legacy Beta

- Prowlarr Cardigann v2 includes several changes such as:
  - Regex removal for Size parsing
  - Multiple Download Selectors
  - Optional Selectors
  - Testlink Torrents
  - InfoHash links
  - AllowRawSearch property in caps
- No new indexers are to be added to v2 as of 2022-04-18
- No new updates backported to v2 as of 2022-04-18

### V3 Indexers - Legacy Beta

- Prowlarr Cardigann v3 includes support for APIs and JSON
- Replace `imdb:` selector with `imdbid:`
- Makes `Description` an optional by default
- All new Indexers using APIs shall be in v3 as of 2021-10-21
  - Indexers utilizing CategoryDescr or any v4 features MUST be in v4

### [V4 Indexers](https://github.com/Prowlarr/Prowlarr/pull/828) - [Dev 0.2.0.1678](https://github.com/Prowlarr/Prowlarr/releases/tag/v0.2.0.1678)

- Prowlarr Cardigann v4 includes several changes such as:
  - TMDBId
  - Genre
  - TraktID
  - CategoryDescr

### [V5 Indexers](https://github.com/Prowlarr/Prowlarr/commit/76afb70b01f4a670d8e402d9a3de05c09611b7ab) - [Dev 0.2.0.1678](https://github.com/Prowlarr/Prowlarr/releases/tag/v0.2.0.1678)

- Prowlarr Cardigann v5 includes several changes such as:
  - Allow JSON Filters

### [V6 Indexers](https://github.com/Prowlarr/Prowlarr/commit/5ee95e3cc29d1307192320eb82b5a8f1287f00d6) - [Dev 0.4.2.1879](https://github.com/Prowlarr/Prowlarr/releases/tag/v0.4.2.1879)

- Prowlarr Cardigann v6 includes several changes such as:
  - `doubanid` support
  - `tmdbid` TV Search Support

### [V7 Indexers](https://github.com/Prowlarr/Prowlarr/commit/ee6467073f64cfaa5ef0de2225f39f0fd0eb5c05) - [Dev 0.4.4.1947](https://github.com/Prowlarr/Prowlarr/releases/tag/v0.4.4.1947)

- Prowlarr Cardigann v7 includes several changes such as:
  - `Publisher`, `Year`, `Genre`, Query support

### [V8 Indexers](https://github.com/Prowlarr/Prowlarr/commit/1529527af9d2bf09dcd1b540b4c6f95a7dd00bd1) - [Dev 1.1.0.2322](https://github.com/Prowlarr/Prowlarr/releases/tag/v1.1.0.2322)

- Prowlarr Cardigann v8 includes several changes such as:
  - HtmlEncode and HtmlDecode filters

### [V9 Indexers](https://github.com/Prowlarr/Prowlarr/commit/bceebc34c134db8140a307e25312cb15e0ff5d63) - [Dev 1.4.0.3230](https://github.com/Prowlarr/Prowlarr/releases/tag/v1.4.0.3230)

- Prowlarr Cardigann v9 includes several changes such as:
  - AllowEmptyInputs
  - default values
  - MissingAttributeEqualsNoResults
