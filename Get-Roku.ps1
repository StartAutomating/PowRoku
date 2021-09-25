function Get-Roku
{
    <#
    .Synopsis
        Gets Rokus
    .Description
        Gets Rokus and information from Rokus.
    .Link
        Find-Roku
    .Example
        Get-Roku  # Get basic info
    .Example
        Get-Roku -App # Get Roku apps
    .Example
        Get-Roku -Screensaver # Get the Roku media player
    #>
    [CmdletBinding(DefaultParameterSetName='query/device-info')]
    [OutputType([PSObject])]
    param(
    # The IP Address of the Roku.  If not provided, all discovered rokus will be contacted.
    [Parameter(ValueFromPipelineByPropertyName)]
    [IPAddress[]]
    $IPAddress,

    # If set, will get device information about the Roku.
    [Parameter(ParameterSetName='query/device-info')]
    [switch]
    $DeviceInfo,

    # If set, will get apps from the Roku.
    [Parameter(Mandatory,ParameterSetName='query/apps')]
    [Alias('Apps')]
    [switch]
    $App,

    # If set, will get the Active App on the Roku.
    [Parameter(Mandatory,ParameterSetName='query/active-app')]
    [switch]
    $ActiveApp,

    # If set, get Screensavers installed on the Roku.
    [Parameter(Mandatory,ParameterSetName='query/screensavers')]
    [Alias('Screensavers')]
    [switch]
    $Screensaver,

    # If set, get Screensavers installed on the Roku.
    [Parameter(Mandatory,ParameterSetName='query/themes')]
    [Alias('Themes')]
    [switch]
    $Theme,

    # If set, will get tv channels from the Roku.
    # This is only supported for Roku TVs.
    [Parameter(Mandatory,ParameterSetName='query/tv-channels')]
    [Alias('Channel', 'Channels','TVChannels')]
    [switch]
    $TVChannel,

    # If set, will get the active channel from the Roku.
    # This is only supported for Roku TVs.
    [Parameter(Mandatory,ParameterSetName='query/tv-active-channel')]
    [switch]
    $ActiveTVChannel,

    # If set, will get media player information from the Roku.
    [Parameter(Mandatory,ParameterSetName='query/media-player')]
    [switch]
    $MediaPlayer,

    # If set, will list Rokus that have already been discovered with Find-Roku.
    # If no Rokus have been discovered, it will attempt to find them.
    [Parameter(Mandatory,ParameterSetName='KnownRokus')]
    [Alias('Discovered')]
    [switch]
    $Discover
    )

    begin {
        filter decorate([string[]]$Typename) {
            $_.pstypenames.clear()
            foreach ($tn in $Typename) {
                $_.pstypenames.add($tn)
            }
            $_
        }
    }

    process {
        $psParameterSet = $PSCmdlet.ParameterSetName
        $isQuery, $thingWeQuery = $PSCmdlet.ParameterSetName -split '/'
        if ($isQuery -eq 'query' -and $thingWeQuery) {
            #region Querying for Data
            if (-not $IPAddress -or 
                $IPAddress -eq [IPAddress]::Broadcast) {
                if (-not $script:CachedDiscoveredRokus) {
                    Find-Roku | Out-Null
                }
                if ($script:CachedDiscoveredRokus) {
                    $IPAddress = $script:CachedDiscoveredRokus | Select-Object -ExpandProperty IPAddress
                } else {
                    Write-Error "No Rokus found"
                    return
                }
            }
            
            foreach ($ip in $IPAddress) {
                $queryData = Send-Roku -IPAddress $ip -Command $PSCmdlet.ParameterSetName
                switch ($thingWeQuery) {
                    'apps' {
                        $queryData |
                            Select-Object -ExpandProperty Apps |
                            Select-Object -ExpandProperty App |
                            decorate Roku.App
                    }
                    'themes' {
                        $queryData | 
                            Select-Object -ExpandProperty Themes |
                            Select-Object -ExpandProperty Theme |
                            ForEach-Object {
                                [PSCustomObject][Ordered]@{
                                    Name = $_.'#text'
                                    Id   = $_.id
                                    Selected = if ($_.'selected') { $true } else { $false }
                                }
                            } |
                            decorate Roku.Theme

                    }
                    'screensavers' {
                        $queryData |
                            Select-Object -ExpandProperty Screensavers |
                            Select-Object -ExpandProperty Screensaver |
                            decorate Roku.Screensaver, Roku.App
                    }
                    'media-player' {
                        $queryData |
                            Select-Object -ExpandProperty Player |
                            decorate "Roku.MediaPlayer"
                    }
                    'tv-channels' {
                        $queryData |
                            Select-Object -ExpandProperty tv-channels |
                            Select-Object -ExpandProperty channel |
                            decorate "Roku.TV.Channel"
                    }
                    'device-info' {
                        $queryData |
                            Select-Object -ExpandProperty device-info |
                            Add-Member NoteProperty IPAddress $IPAddress -Force -PassThru |
                            decorate $(
                                if ($DeviceInfo) {
                                    "Roku.Device"
                                } else {
                                    "Roku.Device#Basic", "Roku.Device"
                                })
                    }
                    default {
                        $queryData
                    }
                }
            }
            #endregion Querying for Data
        }
        elseif ($psParameterSet -eq 'KnownRokus') {
            #region Output known Rokus
            Find-Roku # If this has already run, it will return the cached rokus.
            #endregion Output known Rokus
        }
    }
}
