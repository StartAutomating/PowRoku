function Start-Roku
{
    <#
    .Synopsis
        Starts a Roku or Roku App.
    .Description
        Starts a Roku, Starts a Roku App, or Sends a Wake-on-Lan to a -MACAddress to Power-On a Roku.
    .Link
        Get-Roku
    .Example
        Get-Roku -App |
            Where-Object { $_.Name -eq 'Netflix' } |
            Start-Roku
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low',DefaultParameterSetName='StartRoku')]
    [OutputType([xml])]
    param(
    # The Roku IP Address
    [Parameter(Mandatory,ParameterSetName='StartRokuApp',ValueFromPipelineByPropertyName)]
    [Parameter(Mandatory,ParameterSetName='StartRoku',ValueFromPipelineByPropertyName)]
    [IPAddress]
    $IPAddress,

    # The Roku App ID.
    [Parameter(Mandatory,ParameterSetName='StartRokuApp',ValueFromPipelineByPropertyName)]
    [string]
    $RokuAppID,

    # The parameters to the Roku app.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='StartRokuApp')]
    [Collections.IDictionary]
    $Parameter,

    # The MAC address of the Roku.
    # This is used to send a wake-on-lan message that will power on a Roku.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='WakeRoku')]
    [string]
    $MACAddress
    )

    process {

        switch ($PSCmdlet.ParameterSetName) {
            StartRoku {
                #region Press PowerOn (not all Rokus)
                Send-Roku -IPAddress $IPAddress -Command 'keypress/PowerOn' -Method POST -Data ''
                #endregion Press PowerOn (not all Rokus)
            }
            WakeRoku {
                #region Send Wake on LAN
                $target=
                    foreach ($_ in $MACAddress -split '[:\-.]') {
                        [convert]::ToByte("$_",16) # Convert each part of the MAC to bytes
                    }


                $packet = # Construct the Wake-On-Lan packet,
                    (,[byte]255 * 6) + # which is 6 bytes of 255,
                    ($target * 16)     # followed by the MAC address repeated 16 times.

                $wakeSent = # Assign WakeSent to true
                    try {
                        $UDPclient = [Net.Sockets.UdpClient]::new()  # If we can open the socket
                        $UDPclient.Connect([IPAddress]::Broadcast,9) # and broadcast
                        [void]$UDPclient.Send($packet, 102)          # our packet.
                        $true
                    } catch {
                        $_ # If we had a problem, assign WakeSent to that problem
                    } finally {
                        $UDPclient.Dispose()
                    }

                # Output the status of our WakeOnLan attempt.  It's up to the network now.
                [PSCustomObject]@{WakeOnLanSent = $wakeSent;MACAddress = $MACAddress}
                #endregion Send Wake on LAN
            }
            StartRokuApp {
                # Roku Apps are launched with the endpoint
                $rokuUrl = "launch/$RokuAppID" # launch/$RokuAppId

                if ($Parameter.Count) {
                    $rokuUrl += "?" # Parameters are sent as query parameters
                    $rokuUrl += @(foreach ($kv in $Parameter.GetEnumerator()) {
                        $kv.Key + '=' +
                        [Web.HttpUtility]::UrlEncode($kv.Value) # (don't forget to encode the value)
                    }) -join '&'
                }

                # Once we have the parameters ready, send an empty POST to the endpoint.
                Send-Roku -IPAddress $IPAddress -Command $rokuUrl -Method POST -Data ''
            }
        }
    }
}
