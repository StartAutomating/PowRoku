function Stop-Roku
{
    <#
    .Synopsis
        Powers off a Roku
    .Description
        Attempts to Power off a Roku by sending the virtual key "PowerOff".

        This key may not be supported on your Roku device.
    .Link
        Get-Roku
    .Link
        Start-Roku
    .Example
        Get-Roku | Stop-Roku
    #>
    [OutputType([Nullable])]
    param(
    # The IP Address of the Roku
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [IPAddress]
    $IPAddress
    )

    process {
        #region Press PowerOff (not all Rokus)
        Send-Roku -IPAddress $IPAddress -Command keypress/PowerOff -Method POST -Data '' |
            Out-Null
        #region Press PowerOff (not all Rokus)
    }
}
