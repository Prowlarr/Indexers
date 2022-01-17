#Requires -Version 7 -Modules powershell-yaml

<#
    .SYNOPSIS
        Name: Invoke-NewznabToCardigannYML.ps1
        The purpose of this script is to convert a Newznab response and generate a Cardigann compatible YML definition
    .DESCRIPTION
        Ingests a given Usenet Indexer that follows the Newznab standard (APIKey optional; site dependent) and outputs a named Cardigann YML
    .NOTES
        This script has been tested on Windows PowerShell 7.1.3
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -indexer "nzbplanet" -privacy "private" -apipath "/api" -outputfile "C:\Development\Code\Prowlarr_Indexers\definitions\v4\nzbplanet.yml" -language "en-US"
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -indexer "nzbplanet" -privacy "public"
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -indexer "nzbplanet" -privacy "semi-private"
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 0)]
    [string]$site,
    [Parameter(Position = 1)]
    [string]$indexer,
    [Parameter(Position = 2)]
    [string]$privacy,
    [Parameter(Position = 3)]
    [string]$apipath = '/api',
    [Parameter(Position = 4)]
    [System.IO.FileInfo]$outputfile = ".$([System.IO.Path]::DirectorySeparatorChar)newznab.yml",
    [Parameter(Position = 5)]
    [string]$language = 'en-US'
)

# Generate Caps Call
[string]$capsCall = ($site + $apipath + '?t=caps')


function Invoke-CatNameReplace
{
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    return ($Name -replace 'xbox', 'XBox' -replace 'ebook', 'EBook' -replace 'XBox One', 'XBox One' -replace 'WiiWare/VC', 'Wiiware' -replace 'Pc', 'PC')
}

function Invoke-ModesReplace
{
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    return ($Name -replace 'rid', 'TVRageID' -replace 'tmdbid', 'TMDBID' -replace 'tvdbid', 'TVDBID' -replace 'imdbid', 'IMDBIDShort' -replace 'traktid', 'TraktId' -replace 'season', 'Season' -replace 'ep', 'Ep' -replace 'album', 'Album' -replace 'artist', 'Artist' -replace 'label', 'Label' -replace 'genre', 'Genre' -replace 'year', 'Year' -replace 'tvmazeid', 'TVMazeID')
}
function Invoke-YMLReplace
{
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    return ($Name -replace 'category2', 'category' -replace '"{ ', '{ ' -replace ' }"', ' }')
}
# Get Data and digest objects
Write-Information 'Requesting Caps'
[xml]$xmlResponse = (Invoke-WebRequest -Uri $capscall -Headers $headers -ContentType 'application/xml' -Method Get).Content
$rSearchCaps = $xmlResponse.caps.searching
$rCategories = $xmlResponse.caps.categories.category
$rServer = $xmlResponse.caps.server
Write-Information 'Got Caps'
# Caps
[string]$q_search = "[$($rSearchCaps.search.supportedParams -replace 'group, ',''  -replace ', ',',' )]"
[string]$movie_search = "[$($rSearchCaps.'movie-search'.supportedParams -replace ', ',',')]"
[string]$tv_search = "[$($rSearchCaps.'tv-search'.supportedParams -replace ', ',',')]"
[string]$book_search = "[$($rSearchCaps.'book-search'.supportedParams -replace ', ',',')]"
[string]$audio_search = "[$($rSearchCaps.'audio-search'.supportedParams -replace ', ',',')]"
Write-Information 'Search Caps Built'
# Get Categories: ID, MappedName, Name
[System.Collections.Generic.List[System.Object]]$categories = @()
Write-Information 'Building Categories'
foreach ($category in $rCategories)
{
    $catName = Invoke-CatNameReplace -Name $category.name
    $temp = [PSCustomObject][ordered]@{
        id   = $category.id
        cat  = $catName
        desc = "'$($category.name)'"
    }
    $categories.Add($temp)
    Write-Information 'Building Sub-Categories'
    foreach ($subcategory in $category.subcat)
    {
        $subcatName = Invoke-CatNameReplace -Name "$($catName)/$($subcategory.name)"
        $subtemp = [PSCustomObject][ordered]@{
            id   = $subcategory.id
            cat  = $subcatName
            desc = "'$($catName)/$($subcategory.name)'"
        }
        $categories.Add($subtemp)
    }
}
Write-Information 'Categories Built'
[System.Collections.Generic.List[string]]$ymlCategories = @()
foreach ($category in ($categories | Sort-Object id))
{
    # TODO: This is currently causing the output to be a list of strings
    $ymlCategories.Add("{ id: $($category.id), cat: $($category.cat), desc: $($category.desc) }")
}
# TODO: Validate Categories List (Names) - use newznabcats.txt
# None matching categories (case insensitive) will need to be commented out - fuzzy match if possible?
Write-Information 'Categories converted to YML'

#TODO: This is currently creating strings for each mode and these shouldn't be strings
$modes = [ordered]@{
    search = $q_search
}

if ($tv_search -ne '[]')
{
    $modes['tv-search'] = $tv_search
}
if ($movie_search -ne '[]')
{
    $modes['movie-search'] = $movie_search
}
if ($book_search -ne '[]')
{
    $modes['book-search'] = $book_search
}
if ($audio_search -ne '[]')
{
    $modes['audio-search'] = $audio_search
}

$inputs = [ordered]@{
    t      = '{{ .Query.Type }}'
    apikey = '{{ .Config.apikey }}'
    q      = '{{ .Keywords }}'
}

foreach ($searchinput in ($modes.GETENUMERATOR() | ForEach-Object { $_.VALUE }).Replace('q', '').Replace('[', '').Replace(']', '').Split(',') | Sort-Object)
{
    if ($searchinput -ne 'q' -and $searchinput -ne '')
    {
        #return $searchinput
        [string]$searchstring = $(Invoke-ModesReplace -Name $($searchinput))
        $inputs.Add($($searchinput), "{{ .Query.$($searchstring)}}")
    }
}
Write-Information 'Search Caps converted to YML & Search Inputs created'

$inputs.Add('cat', '{{ join .Categories \", \" }}')
$inputs.Add('raw', '&extended=1')

if (!$indexer)
{
    $indexer = $($rServer.title).replace(' - NZB', '')
}
if ($outputfile.Name -eq 'newznab.yml')
{
    $outputfile = "../definitions/v5/$([System.IO.Path]::DirectorySeparatorChar)$($indexer.Replace(' ','').ToLower()).yml"
}
[string]$indexerstrap = $($rServer.strapline)
[string]$indexerdescr = "'$($indexer) is a $($privacy.ToUpper()) Newznab Usenet Indexer'"
if (!$indexerstrap)
{
    $indexerdescr = $indexerstrap
}
Write-Information 'Building YML'
$hashTable = [ordered]@{
    id                    = "$($indexer.Replace(' ','').ToLower())-yml"
    name                  = $indexer
    description           = $indexerdescr
    language              = $language
    type                  = $privacy.ToLower()
    allowdownloadredirect = $true
    implementation        = 'newznab'
    encoding              = 'UTF-8'
    links                 = @($rServer.url)
    caps                  = [ordered]@{
        categorymappings = $ymlCategories
        modes            = $($modes)
    }
    settings              = @([ordered]@{
            name  = 'apikey'
            type  = 'text'
            label = 'Site API Key'
        }
    )
}
Write-Information 'YML Built'

$ymlout = '---
'
$ymlout += (Invoke-YMLReplace -Name $($hashTable | ConvertTo-Yaml))
$ymlout = ($ymlout).replace("'[", '[')
$ymlout = ($ymlout).replace("]'", ']')
$ymlout = ((($ymlout) -replace '\\\\', '\') -replace '---', '---').Trim()
$ymlout += '
# newznab standard'
# return $ymlout

Write-Information 'Indexer YML Complete'
$ymlout | Out-File $OutputFile -Encoding 'UTF-8'
Write-Information 'Indexer YML Page Output - [$OutputFile]'
