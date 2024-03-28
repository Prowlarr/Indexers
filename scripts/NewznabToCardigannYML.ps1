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
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -indexer "NzbPlanet" -privacy "private" -apipath "/api" -outputfile "C:\Development\Code\Prowlarr_Indexers\definitions\v4\nzbplanet.yml" -language "en-US"
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -indexer "NzbPlanet" -privacy "public"
    .EXAMPLE
    PS> .\NewznabToCardigannYML.ps1 -site https://nzbplanet.net -indexer "NzbPlanet" -privacy "semi-private"
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
    # Order of the below matters as certain broader categories need replacing first
    # must be alpha sorted; creplace and ireplace used for sorts
    return (
        $Name `
            -creplace 'Misc', 'Other' `
            -creplace 'TV/Documentary', 'TV/Dokum' `
            -creplace 'TV/Documentarys', 'TV/Dokum' `
            -creplace "TV/Documentary's", 'TV/Dokum' `
            -ireplace 'Apps', 'PC' `
            -ireplace 'Audio ', 'Audio' `
            -ireplace 'Games', 'Console' `
            -ireplace 'Gaming', 'Console' `
            -ireplace 'PC/Mobile', 'PC/Mobile-Other' `
            -ireplace 'Software', 'PC' `
            -ireplace 'Spiele', 'Console' `
            -ireplace 'TV/Doc', 'TV/Dokum' `
            -ireplace 'TV/Dokums', 'TV/Dokum' `
            -ireplace 'XXX ', 'XXX' `
            -ireplace "TV/Dokum's", 'TV/Dokum' `
            -replace '/Playstation ', '/PS' `
            -replace '4K', 'UHD' `
            -replace 'Adult', 'XXX' `
            -replace 'Anime', 'TV/Anime' `
            -replace 'Audio/Books', 'Audio/Audiobook' `
            -replace 'Books/TV/Anime', 'Books' `
            -replace 'Console/360 DLC', 'Console/XBox 360 DLC' `
            -replace 'Console/PC', 'PC/Games'  `
            -replace 'Console/PS Vita', 'Console/PS Vita' `
            -replace 'Console/PSVita', 'Console/PS Vita' `
            -replace 'Console/Switch', 'Console/Other' `
            -replace 'EBook Non-English', 'Foreign' `
            -replace 'EBook Technical', 'Technical' `
            -replace 'ebook', 'EBook' `
            -replace 'Gaming/PC', 'PC/Games' `
            -replace 'ImgSet', 'ImageSet' `
            -replace 'M-Android', 'Mobile-Android' `
            -replace 'M-iOS', 'Mobile-iOS' `
            -replace 'Magazine', 'Mag' `
            -replace 'Movies/1080P', 'Movies/HD' `
            -replace 'Movies/2160P', 'Movies/UHD' `
            -replace 'Movies/720P', 'Movies/HD' `
            -replace 'Movies/Cam', 'Movies/Other' `
            -replace 'Movies/Mobile', 'Movies/Other' `
            -replace 'Movies/Non-English', 'Movies/Foreign' `
            -replace 'Movies/Packs', 'Movies/Other' `
            -replace 'Movies/X265', 'Movies' `
            -replace 'Other/Ebook', 'Books/Other' `
            -replace 'Other/Obfuscated', 'Other/Hashed' `
            -replace 'Other/Other', 'Other/Misc' `
            -replace 'Other/Spam', 'Other/Hashed' `
            -replace 'Other/TV/Anime', 'TV/Anime' `
            -replace 'Pc', 'PC' `
            -replace 'PC/Android', 'PC/Mobile-Android' `
            -replace 'PC/Apple', 'PC/Mac' `
            -replace 'PC/Console', 'PC/Games'  `
            -replace 'PC/iOS', 'PC/Mobile-iOS' `
            -replace 'PC/Mobile-Other-android', 'PC/Mobile-Android' `
            -replace 'PC/Mobile-Other-ios', 'PC/Mobile-iOS' `
            -replace 'PC/Mobile-Other-Other', 'PC/Mobile-Other' `
            -replace 'PC/PC', 'PC' `
            -replace 'PC/Phone-', 'PC/Mobile-' `
            -replace 'TV/ TV/Anime', 'TV/Anime' `
            -replace 'TV/1080P', 'TV/HD' `
            -replace 'TV/2160P', 'TV/UHD' `
            -replace 'TV/720P', 'TV/HD' `
            -replace 'TV/Dokum', 'TV/Documentary' `
            -replace 'TV/Dokus', 'TV/Documentary' `
            -replace 'TV/Non-English', 'TV/Foreign' `
            -replace 'TV/TV/Anime', 'TV/Anime' `
            -replace 'TV/X265', 'TV' `
            -replace 'WEBDL', 'WEB-DL' `
            -replace 'WiiWare/VC', 'Wiiware' `
            -replace 'XBOX 360 DLC', 'XBox 360 DLC' `
            -replace 'XBOX DLC', 'XBox 360 DLC' `
            -replace 'xbox', 'XBox' `
            -replace 'XboxOne', 'XBox One' `
            -replace 'XXX/HD Clips', 'XXX' `
            -replace 'XXX/HD', 'XXX' `
            -replace 'XXX/Packs', 'XXX/Pack' `
            -replace 'XXX/SD Clips', 'XXX' `
            -replace 'XXX/SD', 'XXX/SD' `
            -replace 'XXX/VR', 'XXX/Other' `
            -replace "'", '' `
    )
}

function Invoke-ModesReplace
{
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    return ($Name `
            -replace 'album', 'Album' `
            -replace 'artist', 'Artist' `
            -replace 'ep', 'Ep' `
            -replace 'genre', 'Genre' `
            -replace 'imdbid', 'IMDBIDShort' `
            -replace 'label', 'Label' `
            -replace 'rid', 'TVRageID' `
            -replace 'season', 'Season' `
            -replace 'tmdbid', 'TMDBID' `
            -replace 'traktid', 'TraktId' `
            -replace 'tvdbid', 'TVDBID' `
            -replace 'tvmazeid', 'TVMazeID' `
            -replace 'year', 'Year' `
    )
}
function Invoke-YMLReplace
{
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    # double brackets
    # double quoted single bracket
    # single quoted single bracket
    # YML 2nd category
    return ($Name `
            -replace '{{', "'{{" `
            -replace '}}', "}}'" `
            -replace 'category2', 'category' `
            -replace "'{", '{' `
            -replace "}'", '}' `
            -replace ' }"', ' }' `
            -replace '"{ ', '{ ' `
            -replace "`"'", '"' `
            -replace "'`"", '"' `
    )
}
# Get Data and digest objects
Write-Information 'Requesting Caps'
$response = Invoke-RestMethod -Uri $capscall -ContentType 'application/xml' -Method Get -StatusCodeVariable 'APIResponseCode' -SkipHttpErrorCheck
if ($APIResponseCode -ne 200)
{
    throw "The status code [$($APIResponseCode)] was received from the website [$($capscall)], please investigate why and try again when issue is resolved"
}
$xmlResponse = [xml]$response
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
Write-Information 'Building Categories'
# TODO: Validate Categories List (Names) - use newznabcats.txt
# None matching categories (case insensitive) will need to be commented out - fuzzy match if possible?
[System.Collections.Generic.List[string]]$ymlCategories = @()
foreach ($category in ($rCategories | Sort-Object id))
{
    $catName = Invoke-CatNameReplace -Name $category.name
    $ymlCategories.Add("{ id: $($category.id), cat: $($catName), desc: $($category.name) }")
    Write-Information "Building Sub-Categories within $($category.id)"
    foreach ($subcategory in ($category.subcat | Sort-Object id))
    {
        $subcatName = Invoke-CatNameReplace -Name "$($catName)/$($subcategory.name)"
        $ymlCategories.Add("{ id: $($subcategory.id), cat: $($subcatName), desc: $($catName)/$($subcategory.name -replace "'", '') }")
    }
}
Write-Information 'Categories Built'
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
        # return $searchinput
        [string]$searchstring = $(Invoke-ModesReplace -Name $($searchinput))
        # dont add input if already exists
        if (!($inputs.Contains($searchinput)))
        {
            $inputs.Add($($searchinput), "{{ .Query.$($searchstring)}}")
        }
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
if (!$indexerstrap -and $indexerstrap -ne '')
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
$ymlout | Out-File $OutputFile -Encoding utf8
$categoryCsv = Import-Csv $($PSScriptRoot + [system.Io.Path]::DirectorySeparatorChar + 'newznabcats(v4.0).csv')
[System.Collections.Generic.List[string]]$linesToReplace = @()
$ymlout = Get-Content $OutputFile -Encoding utf8
# validating Category Names
Write-Information 'Validating Categories'
foreach ($line in ($ymlout | Select-String '{ id:' | Select-Object -ExpandProperty Line))
{
    foreach ($cleanLine in ($line -replace '- { ', '' -replace ' }' -replace 'id: ' -replace 'cat: ' -replace 'desc: ').Trim())
    {
        # Replace Spaces to _ to avoid word splitting
        $split = (($cleanLine -split ',').Trim())
        # Check if YML's Generated Newznab Category exists within the Cardigann Newznab Category List
        $categoryCsvCategory = ((($categoryCsv | Where-Object { $_.newznabcat -eq $split[1] }).newznabcat))
        # Replace Spaces to _ to avoid word splitting
        if ($categoryCsvCategory -ne $split[1])
        {
            Write-Warning "YML Category of Indexer ID [$($split[0])] parsed as Category [$($split[1])] from Indexer's Category Name [$($split[2])] is not Newznab Standard. Category disabled in YML"
            $linesToReplace.Add($line)
        }
    }
}
$ymlCleanedOutput = $ymlout
if ($linesToReplace.Count -gt 0)
{
    foreach ($lineToReplace in $linesToReplace)
    {
        $ymlCleanedOutput = $ymlCleanedOutput -replace $lineToReplace, "#$lineToReplace"
    }
}

$ymlCleanedOutput | Out-File $OutputFile -Encoding utf8 -Force
Write-Information 'Indexer YML Page Output - [$OutputFile]'
