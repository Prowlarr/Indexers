<#
    .SYNOPSIS
        Name: Invoke-NewznabToCardigannYML.ps1
        The purpose of this script is to convert a Newznab response and generate a Cardigann compatible YML definition
    .DESCRIPTION
        Ingests a given Usenet Indexer that follows the Newznab standard (APIKey optional; site dependent) and outputs a named Cardigann YML
    .NOTES
        This script has been tested on Windows PowerShell 7.1.3
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -apikey "SomeKey" -indexer "nzbplanet"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 1) ]
    [string]$site,
    [Parameter(Position = 2) ]
    [string]$apikey,
    [Parameter(Position = 3)]
    [string]$indexer
)

# Generate Caps Call
[string]$capsCall = ($site + '/api?t=caps&apikey=' + $apikey)

# Get Data and digest objects
[xml]$xmlResponse = (Invoke-WebRequest -Uri $capscall -Headers $headers -ContentType 'application/xml' -Method Get).Content
$rSearchCaps = $xmlResponse.caps.searching
$rCategories = $xmlResponse.caps.categories

# Caps
[string]$q_search = ($rSearchCaps.search.supportedParams)
[string]$movie_search = ($rSearchCaps.'movie-search'.supportedParams)
[string]$tv_search = ($SearchCaps.'tv-search'.supportedParams)
[string]$book_search = ($rSearchCaps.'book-search'.supportedParams)
[string]$audio_search = ($rSearchCaps.'music-search'.supportedParams)

# Get Main Categories: ID, Name
[array]$maincats = @( $rCategories.category.id, $rCategories.category.name )


# Get Sub Categories  Main ID, ID, Name
# ToDo: Fix this it is creating a new entry for each rather than concating to a base category
[array]$subcats = @(($rCategories.category.subcat.id.SubString(0, 1) + '000'), $rCategories.category.subcat.id, $rCategories.category.subcat.name)


# Cleanup Common Category naming issues
# ToDo: Change the find/replaces to an array input
$maincats = $maincats -replace 'xbox', 'XBox' -replace 'ebook', 'EBook' -replace 'XBox One', 'XBox One' -replace 'WiiWare/VC', 'Wiiware' -replace 'Pc', 'PC'
$subcats = $subcats -replace 'xbox', 'XBox' -replace 'ebook', 'EBook' -replace 'XBox One', 'XBox One' -replace 'WiiWare/VC', 'Wiiware' -replace 'Pc', 'PC'

# ToDo: Join to get main cat and create proper subcat names
#$subcats = $subcats | Join $maincats on id

# ToDo: Validate Categories List (Names) - use newznabcats.txt
# None matching categories (case insensitive) will need to be commented out

# ToDo: Create YML file from given data inputs

# write host for Debugging Only
Write-Host ('Indexer site is [' + "$site" + ']')
Write-Host ('Search Caps are [' + "$q_search" + ']')
Write-Host ('Movie Caps are [' + "$movie_search" + ']')
Write-Host ('TV Caps are [' + "$tv_search" + ']')
Write-Host ('Book Caps are [' + "$book_search" + ']')
Write-Host ('Music Caps are [' + "$audio_search" + ']')
Write-Host ('Main Cat are [' + "$maincats" + ']')
Write-Host ('Sub Cat are [' + "$subcats" + ']')