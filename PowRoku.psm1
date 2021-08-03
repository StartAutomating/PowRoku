if (-not ('Web.HttpUtility' -as [Type])) {
    Add-Type -AssemblyName System.Web
}
foreach ($file in Get-ChildItem -Path $PSScriptRoot -Filter *-*.ps1) {
    if ($file.Name -notlike '*.*.ps1') {
        . $file.fullname
    }
}
