# Indexers

This Repo contains Cardigann YML indexer definitions for [Prowlarr](https://github.com/Prowlarr/Prowlarr).

For more information on the formatting of the YML Indexer Definition, please see [our Prowlarr Cardigann YML Version / Definition wiki entry](https://wiki.servarr.com/en/prowlarr/cardigann-yml-definition)

For Prowlarr Indexer Requests; please see [our request site](https://requests.prowlarr.com/)

# Definition Versions

Versions require Prowlarr Cardigann C# modifications.
Prowlarr will fall back to a previous version if no YML exists for the current version.

## Active Versions

- V2 Indexers
  - Prowlarr Cardigann v2 include several changes such as
    - Regex removal for Size parsing
    - Multiple Download Selectors
    - Optional Selectors
    - Testlink Torrents
    - InfoHash links
    - AllowRawSearch property in caps
  - All new indexers shall be added to v2 as of 2021-10-13
- V3 Indexers
  - Prowlarr Cardigann v3 includes support for APIs and JSON
  - Replace `imdb:` selector with `imdbid:`
  - Makes `Description` an optional by default
  - All new Indexers using APIs shall be in v3 as of 2021-10-21
    - Indexers utiizing CategoryDescr or any v4 features MUST be in v4
- V4 Indexers
  - Prowlarr Cardigann v4 includes several changes such as
    - TMDBId
    - Genre
    - TraktID
    - CategoryDescr
- V5 Indexers
  - Prowlarr Cardigann v5 includds several changes such as
    - Allow JSON Filters

## Depreciated Versions

- V1 Indexers
  - Prowlarr Cardigann v1 are base level standard YML
  - No new indexers are to be added to v1 as of 2021-10-13
  - No new updates backported to v1 as of 2021-10-17
