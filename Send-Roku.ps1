function Send-Roku
{
    <#
    .Synopsis
        Sends to the Roku
    .Description
        Sends REST messages to the Roku External Command Protocol.

        or

        Sends a keyboard sequence to a Roku.
    .Link
        Get-Roku
    .Example
        Send-Roku -IPAddress $myRokuIP -Command query/device-info
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low',DefaultParameterSetName='Command')]
    [OutputType([xml], [Nullable])]
    param(
    # The IP Address of the Roku.
    [Parameter(ValueFromPipelineByPropertyName)]
    [IPAddress[]]
    $IPAddress,

    # The URI fragment to send to the Roku.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Command')]
    [string]
    $Command,

    # The HTTP method to send.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Command')]
    [string]
    $Method = 'GET',

    # The text to send.  Each character will be turned into a literal and sent to the Roku.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='Text')]
    [string]
    $Text,

    # Will send a single KeyDown message to the Roku, similar to holding a key down.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='keydown')]
    [string]
    $KeyDown,

    # Will send a single KeyUp message to the Roku, releasing a key that has been held down.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='keyup')]
    [string]
    $KeyUp,

    # Will send a single keypress to the Roku.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='keypress')]
    [string]
    $KeyPress,

    # The data to send.  This will be converted into JSON if it is not a string.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Command')]
    [PSObject]
    $Data,

    # If set, will attempt to mute the device.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='VolumeMute')]
    [switch]
    $Mute,

    # If set, will raise the volume.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='VolumeUp')]
    [switch]
    $VolumeUp,

    # If set, will lower the volume.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='VolumeDown')]
    [switch]
    $VolumeDown,

    # If set, will switch to the TV tuner
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='launch/tvinput.dtv')]
    [switch]
    $TVTuner,

    # If provided, will change the channel on the TV Tuner.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='launch/tvinput.dtv')]
    [double]
    $Channel,

    # If provided, will change the TV Tuner to a given HDMI input.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='launch/tvinput')]
    [ValidateRange(1,10)]
    [uint32]
    $HDMIInput,

    # If set, will change the Roku TV to use it's AV input
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='launch/tvinput')]
    [switch]
    $AVInput,

    # A set of additional properties to add to an object
    [Parameter(ValueFromPipelineByPropertyName)]
    [Collections.IDictionary]
    $Property = @{},

    # A list of property names to remove from an object
    [string[]]
    $RemoveProperty,

    # If provided, will expand a given property returned from the REST api.
    [string]
    $ExpandProperty,

    # The typename of the results.
    [Parameter(ValueFromPipelineByPropertyName)]
    [string[]]
    $PSTypeName
    )

    process {
        #region Broadcast Recursively if no -IPAddress was provided
        if (-not $IPAddress -or 
            $IPAddress -eq [IPAddress]::Broadcast -or 
            $IPAddress -eq [IPAddress]::Any
        ) {
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
        $psParameterSet = $PSCmdlet.ParameterSetName

        foreach ($ip in $ipaddress) {
            if ($psParameterSet -eq 'Text') {
                foreach ($char in $text.ToCharArray()) {
                    $u = [Web.HttpUtility]::UrlEncode("$char")
                    Send-Roku -Command "keypress/Lit_$u" -IPAddress $ip -Method POST -Data ''  |
                    & { process {
                        if ($WhatIfPreference)  {$_ }
                    } }
                }
                continue
            }

            if ($psParameterSet -like "Volume*") {                
                $KeyPress = "$psParameterSet"
                $psParameterSet = 'keypress'
            }

            if ($psParameterSet -like 'key*') {
                $key = $KeyDown, $KeyUp, $KeyPress -ne ''

                Send-Roku -Command "$psParameterSet/$key" -IPAddress $ip -Method POST -Data '' |
                    & { process {
                        if ($WhatIfPreference)  {$_ }
                    } }

                continue
            }

            if ($TVTuner -or $Channel) {
                Send-Roku -Command "$psParameterSet$(if ($Channel) {"?ch=$($channel)"})" -IPAddress $ip -Method POST -Data '' |
                    & { process {
                        if ($WhatIfPreference)  {$_ }
                    } }
                continue
            }

            if ($psParameterSet -eq 'launch/tvinput') {
                $command = "$psParameterSet"

                if ($AVInput) {
                    $Command += ".cvbs"
                } else {
                    $Command += ".hdmi$($HDMIInput)"
                }
                Send-Roku -Command $Command -IPAddress $ip -Method POST -Data '' |
                    & { process {
                        if ($WhatIfPreference)  {$_ }
                    } }
                continue
            }

            


            $splat = @{
                uri = "http://${ip}:8060/$Command"
                method = $Method
            }

            if ($Data) {
                if ($data -is [string]){
                    $splat.body = $data
                } else {
                    $splat.body = ConvertTo-Json -Compress -Depth 10 -InputObject $Data
                }
            }

            if ($WhatIfPreference) {
                $splat
                continue
            }

            if (-not $property) { $property = [Ordered]@{}  }
            $property['IPAddress'] = $ip


            $psProperties = @(
                foreach ($propKeyValue in $Property.GetEnumerator()) {
                    if ($propKeyValue.Value -as [ScriptBlock[]]) {
                        [PSScriptProperty]::new.Invoke(@($propKeyValue.Key) + $propKeyValue.Value)
                    } else {
                        [PSNoteProperty]::new($propKeyValue.Key, $propKeyValue.Value)
                    }
                }
            )

            if (! $PSCmdlet.ShouldProcess("$Method $($splat.Uri)")) { continue }
            if ($WhatIfPreference) { continue } 
            Invoke-RestMethod @splat 2>&1 |
                 & { process {
                    $in = $_
                    if ($in -isnot [xml]) {
                        $inXml = $in -as [xml]
                        if ($inXml) {
                            $in = $inXml
                        }
                    }


                    if (-not $in -or $in -eq 'null') { return }
                    if ($ExpandProperty) {
                        if ($in.$ExpandProperty) {
                            $in.$ExpandProperty
                        }
                    } else {
                        $in # pass it down the pipe.
                    }
                } } 2>&1 |
                & { process { # One more step of the pipeline will unroll each of the values.

                    if ($_ -is [string]) { return $_ }
                    if ($null -ne $_.Count -and $_.Count -eq 0) { return }
                    $in = $_
                    if ($PSTypeName -and # If we have a PSTypeName (to apply formatting)
                        $in -isnot [Management.Automation.ErrorRecord] # and it is not an error (which we do not want to format)
                    ) {
                        $in.PSTypeNames.Clear() # then clear the existing typenames and decorate the object.
                        foreach ($t in $PSTypeName) {
                            $in.PSTypeNames.add($T)
                        }
                    }

                    if ($Property -and $Property.Count) {
                        foreach ($prop in $psProperties) {
                            $in.PSObject.Members.Add($prop, $true)
                        }
                    }
                    if ($RemoveProperty) {
                        foreach ($propToRemove in $RemoveProperty) {
                            $in.PSObject.Properties.Remove($propToRemove)
                        }
                    }
                    if ($DecorateProperty) {
                        foreach ($kv in $DecorateProperty.GetEnumerator()) {
                            if ($in.$($kv.Key)) {
                                foreach ($v in $in.$($kv.Key)) {
                                    if ($null -eq $v -or -not $v.pstypenames) { continue }
                                    $v.pstypenames.clear()
                                    foreach ($tn in $kv.Value) {
                                        $v.pstypenames.add($tn)
                                    }
                                }
                            }
                        }
                    }
                    return $in # output the object and we're done.
                } }
            foreach ($ir in $invokeResult) {

                $ir.psobject.properties.add($ipNoteProperty)
                $ir
            }        
            
        }


        
    }
}

