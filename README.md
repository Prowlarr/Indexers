# Indexers

[![Supported Indexers](https://img.shields.io/badge/Supported%20Indexers-View%20all%20currently%20supported%20indexers%20%26%20trackers-important)](https://wiki.servarr.com/en/prowlarr/supported-indexers)

This Repo contains Cardigann YML indexer definitions for [Prowlarr](https://github.com/Prowlarr/Prowlarr).

For more information on the formatting of the YML Indexer Definition, please see [our Prowlarr Cardigann YML Version / Definition wiki entry](https://wiki.servarr.com/en/prowlarr/cardigann-yml-definition)

To develop and test definitions, you may use the [Custom Definition Folder](https://wiki.servarr.com/prowlarr/indexers#adding-a-custom-yml-definition)

For Prowlarr Indexer Requests; please see [our request site](https://requests.prowlarr.com/)

## Definition Versions

Versions require Prowlarr Cardigann C# modifications.
Prowlarr will fall back to a previous version if no YML exists for the current version.

## Schemas

Each Cardigann Version has a YML Schema for it contained within the definitions's respective folder named `schema.json`
For more specific details between versions the schema files can be compared.

To test a definition file against a specific schema use the command below.

Note that the following npm packages are required `ajv-cli-servarr ajv-formats`  These can be installed globally on your system with

```bash
npm install -g ajv-cli-servarr ajv-formats
```

To test the definition:

```bash
 ajv test -d "definitions/v{VERSION}/{INDEXER FILE NAME}.yml" -s "definitions/v{VERSION}/schema.json" --valid -c ajv-formats --spec=draft2019
```

## Active Versions

- [V8 Indexers](https://github.com/Prowlarr/Prowlarr/commit/1529527af9d2bf09dcd1b540b4c6f95a7dd00bd1) - Dev 1.1.0.2322
  - Prowlarr Cardigann v8 includes several changes such as
    - HtmlEncode and HtmlDecode filters
- [V7 Indexers](https://github.com/Prowlarr/Prowlarr/commit/ee6467073f64cfaa5ef0de2225f39f0fd0eb5c05) - Dev 0.4.4.1947
  - Prowlarr Cardigann v7 includes several changes such as
    - `Publisher`, `Year`, `Genre`, Query support

## Depreciated Versions

### V1 Indexers

- Prowlarr Cardigann v1 are base level standard YML
- No new indexers are to be added to v1 as of 2021-10-13
- No new updates backported to v1 as of 2021-10-17

### V2 Indexers

- Prowlarr Cardigann v2 include several changes such as
  - Regex removal for Size parsing
  - Multiple Download Selectors
  - Optional Selectors
  - Testlink Torrents
  - InfoHash links
  - AllowRawSearch property in caps
- No new indexers are to be added to v2 as of 2022-04-18
- No new updates backported to v2 as of 2022-04-18

### V3 Indexers

- Prowlarr Cardigann v3 includes support for APIs and JSON
- Replace `imdb:` selector with `imdbid:`
- Makes `Description` an optional by default
- All new Indexers using APIs shall be in v3 as of 2021-10-21
  - Indexers utilizing CategoryDescr or any v4 features MUST be in v4

### [V4 Indexers](https://github.com/Prowlarr/Prowlarr/pull/828) - Dev 0.2.0.1678
- Prowlarr Cardigann v4 includes several changes such as
  - TMDBId
  - Genre
  - TraktID
  - CategoryDescr

### [V5 Indexers](https://github.com/Prowlarr/Prowlarr/commit/76afb70b01f4a670d8e402d9a3de05c09611b7ab) - Dev 0.2.0.1678
- Prowlarr Cardigann v5 includes several changes such as
  - Allow JSON Filters

### [V6 Indexers](https://github.com/Prowlarr/Prowlarr/commit/5ee95e3cc29d1307192320eb82b5a8f1287f00d6) - Dev 0.4.2.1879
- Prowlarr Cardigann v6 includes several changes such as
  - `doubanid` support
  - `tmdbid` TV Search Support
