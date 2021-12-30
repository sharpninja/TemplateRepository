#! pwsh
param (
    [string]$ProfileName = $null,
    [string]$RootFolder = './test',
    [string]$Name = 'test',
    [switch]$List = $false,
    [switch]$Verbose = $false,
    [switch]$WhatIf = $false,
    [switch]$Force = $False,
    [switch]$Confirm = $False
)

$VerbosePreference=$Verbose
$WhatIfPreference=$WhatIf

Import-Module .\RepoBuilder.psm1

if ($List) {
    Get-Profiles
}
elseif($null -ne $ProfileName) {
    '[init.ps1] Entering...'
    Invoke-Profile -ProfileName $ProfileName `
        -RootFolder $RootFolder `
        -Name $Name `
        -Verbose:$Verbose -WhatIf:$WhatIf `
        -Force:$Force -Confirm:$Confirm
    '[init.ps1] Exiting...'
} else {
    'Display usage.'
}
