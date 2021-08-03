PowRoku is a nifty little PowerShell module to help automate your Roku(s).

It is built atop the [Roku External Control Protocol](https://developer.roku.com/docs/developer-program/debugging/external-control-api.md).

You can use PowRoku to control Roku devices and Roku TVs.

Assuming you have a Roku TV, and it's on, use this to try it out:

~~~PowerShell
Find-Roku                 # Find your Rokus

Find-Roku | Get-Roku -App # Get all of the Apps on each Roku

Find-Roku | Get-Roku -ActiveApp # Get the Active App on each Roku

Find-Roku | Stop-Roku     # Turn your Roku TV off (only works for Rokus which support PowerOff)

# Turn up the volume
Send-Roku -Method POST -Data '' -Command Keypress/VolumeUp

Find-Roku | 
    Get-Roku -App | 
    Where-Object { $_.Name -eq 'Netflix' } | 
    Start-Roku

Start-Roku -MacAddress $myRokuMac # Send a Wake-on-Lan to your Roku's MACAddress
~~~
