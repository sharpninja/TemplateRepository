using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO


class Config {
    [string]$RootFolder
    [string]$Name = $Name
    [string]$SolutionFolder
    [string]$SolutionFile
    [switch]$Verbose = $V;
    [switch]$WhatIf = $WhatIf;
    [switch]$Force = $Force;
    [switch]$Confirm = $Confirm;
    $GitCommand = (Get-Command git -ErrorAction SilentlyContinue)
    $DotnetCommand = (Get-Command dotnet -ErrorAction SilentlyContinue)
    $GitVersionCommand = (Get-Command dotnet-gitversion -ErrorAction SilentlyContinue)
    $GitignoreCommand = (Get-Command dotnet-gitignore -ErrorAction SilentlyContinue)
    $NugetCommand = (Get-Command nuget -ErrorAction SilentlyContinue)
    $NukeCommand = (Get-Command nuke -ErrorAction SilentlyContinue)
    $CakeCommand = (Get-Command dotnet-cake -ErrorAction SilentlyContinue)
    $DocFxCommand = (Get-Command docfx -ErrorAction SilentlyContinue)
    $EfCoreCommand = (Get-Command dotnet-ef -ErrorAction SilentlyContinue)
    $GrpcCommand = (Get-Command dotnet-grpc -ErrorAction SilentlyContinue)
    $WingetCommand = (Get-Command winget -ErrorAction SilentlyContinue)
    $ChocoCommand = (Get-Command choco -ErrorAction SilentlyContinue)
    $ScoopCommand = (Get-Command scoop -ErrorAction SilentlyContinue)
    $FinishedStages = (New-Object System.Collections.ArrayList)

    [string]ToString() {
        $ht = [Ordered]@{}

        $type = $this.GetType();
        $type.GetProperties() `
        | ForEach-Object -Process {
            [System.Reflection.PropertyInfo]$pi = $_;
            if ($pi.Name -ne 'FinishedStages') {
                $name = $pi.Name
                $value = $pi.GetValue($this);
                $ht.Add($name, $value)
            }
        }

        $result = ($ht | Sort-Object Key | Format-Table Key, Value -AutoSize | Out-String)

        return $result
    }
}

[Config]$Config = $null

$InsertCounter=0

class ActionScript {
    [int]$Index
    [string]$Filename
    [string]$Function

    ActionScript([string]$Filename,
        [string]$Function)
        {
            $this.Index = ($InsertCounter += 1)
            $this.Filename = $FileName
            $this.Function = $Function
        }
}

class Profile {
    [string]$Name
    [ActionScript[]]$Targets
    [Hashtable]$Options

    Profile([string]$n,[ActionScript[]]$t) {
        $this.Name = $n
        $this.Targets = $t
        $this.Options = @{}
    }

    [ActionScript[]]SortedTargets() {
        return ($this.Targets | Sort-Object Index)
    }
}

function Get-AllTargets {
    $GitScript = [ActionScript]::new('Git.ps1', 'Initialize-Git')
    $GitHubScript = [ActionScript]::new('GitHub.ps1', 'Initialize-GitHubWorkflow')

    $AvailableTargets = @();
    $AvailableTargets += [Profile]::new('Blazor-WebApi-EF-DocFx-GitHub', @($GitScript, $GitHubScript))
    $AvailableTargets += [Profile]::new('Blazor-WebApi-EF-DocFx-Azure', @($GitScript))
    $AvailableTargets += [Profile]::new('Blazor-WebApi-MediatR-DocFx-GitHub', @($GitScript, $GitHubScript))
    $AvailableTargets += [Profile]::new('Blazor-WebApi-MediatR-DocFx-Azure', @($GitScript))

    return $AvailableTargets
}
function Initialize-RepoBuilder {
    param (
        [string]$ProfileName = $null,
        [string]$RootFolder = './test',
        [string]$Name = 'test',
        [switch]$Verbose = $false,
        [switch]$WhatIf = $false,
        [switch]$Force = $False,
        [switch]$Confirm = $False
    )

    try {
        $invocation = $MyInvocation.MyCommand
        Write-Verbose -Message "[$invocation] Entered"

        if (-not (Test-Path $RootFolder)) {
            New-Item -Path $RootFolder -ItemType Directory | Out-Null
        }

        if (Test-Path $RootFolder -ErrorAction Stop) {
            $root = Join-Path $RootFolder -Child $Name
            if (-not (Test-Path $root)) {
                New-Item -Path $root -ItemType Directory | Out-Null
            }
            $root = Resolve-Path $root #-ErrorAction SilentlyContinue
            if ($null -eq $root) {
                throw "Cannot resolve path: $(Join-Path $PWD -Child $RootFolder)"
            }
        }
        else {
            throw "Failed to create $RootFolder"
        }

        Write-Verbose -Message "[$invocation] `$root: [$root]"

        $solutionFolder = $root
        $solutionFile = Join-Path $solutionFolder -ChildPath "${Name}.sln"

        [Config]$config = [Config]::new();
        $config.SolutionFolder = $solutionFolder;
        $config.SolutionFile = $solutionFile;
        $config.RootFolder = $RootFolder;
        #$config.Verbose = $V;

        Write-Information -Message "[$invocation] Created Config."

        $c = $config.ToString()
        Write-Verbose -Message $c
        Write-Output $config
    }
    catch {
        $exitCode = $LASTEXITCODE
        $e = $_
        Write-Error $e
        Write-Error $e.ScriptStackTrace
        exit $exitCode
    }
}

function Invoke-Target([Config]$cfg=$Config, [string]$Target) {
    if ($null -eq $Target) {
        $arguments = @("`$Target", "Invoked `Invoke-Target` with ```$null` ```$Target`"")

        $exception = New-Object -Type System.ArgumentNullException -ArgumentList $arguments

        throw $exception
    }

    try {
        $slug = $Target.ToString()
        if (-not $cfg.FinishedStages.Contains($slug)) {
            & $Target

            $cfg.FinishedStages.Add($slug) | Out-Null
        }
    }
    catch {
        $exitCode = $LASTEXITCODE
        $e = $_
        Write-Error $e
        Write-Error $e.ScriptStackTrace
        exit $exitCode
    }
}

function Invoke-Dependency([Config]$cfg=$Config, $Caller, $Target) {
    if ($null -eq $Target) {
        $arguments = @("`$Target", "``$Caller` invoked `Invoke-Dependecy` with ```$null` ```$Target`"")

        $exception = New-Object -Type System.ArgumentNullException -ArgumentList $arguments

        throw $exception
    }

    try {
        if (-not $cfg.FinishedStages.Contains($Target)) {
            Invoke-Target -Target $Target

            Write-Information "Executed $Target as Dependency of $Caller"
        }
        else {
            Write-Verbose -Message "$Target is Dependency of $Caller whach has already completed."
        }
    }
    catch {
        $exitCode = $LASTEXITCODE
        $e = $_
        Write-Error "`$Caller: $Caller"
        Write-Error "`$Target: $Target"
        Write-Error $e
        Write-Error $e.ScriptStackTrace
        exit $exitCode
    }
}

function Exit-IfFails(
    [Config]$cfg = $Config, 
    [string]$scriptBlock = $null,
    [string]$FailureMessage = 'Failed with exitcode {0} executing: {1}') {

    try {
        [string]$inf
        if($null -ne $cfg) {
            $block = [scriptblock]::Create("param(`$cfg) $scriptBlock -cfg `$cfg")
        } else {
            $block = [scriptblock]::Create($scriptBlock)
        }
        Write-Information "[Exit-IfFails] $block"
        $inf = & $block $cfg

        $exitCode = $LASTEXITCODE

        if ($null -eq $inf) {
            $inf = 'Nothing returned on stdout.'
        }

        Write-Information "[$scriptBlock] Exitcode: ${exitCode}, Result: $inf"

        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $e = [System.String]::Format($FailureMessage, $exitCode, $scriptBlock)
            Write-Error $e
            exit $exitCode
        }
    }
    catch {
        $exitCode = $LASTEXITCODE
        $e = $_
        Write-Error $e
        Write-Error $e.ScriptStackTrace
        Write-Error [System.String]::Format($FailureMessage, $exitCode, $scriptBlock)
        exit $exitCode
    }
}
$config
function Set-RootLocation([Config]$cfg = $Config) {
    $root = $cfg.RootFolder
    if ($null -eq $root) {
        throw "`$cfg.RootFolder is `$null."
    }
    if (-not (Test-Path $root)) {
        New-Item $root -ItemType Directory | Out-Null
    }

    Set-Location $root | Out-Null
}

function Get-AvailableProfiles {
    
        $AvailableTargets = Get-AllTargets
        Write-Verbose -Message "[Get-AvailableProfiles] `$AvailableTargets.Count: $($AvailableTargets.Count)."

        if ($null -eq $profileNames) {
            [System.Collections.ArrayList]$profileNames = New-Object System.Collections.ArrayList
            Write-Verbose -Message "[RepoBuilder] Created `$profileNames as ArrayList: $($null -ne $profileNames)"
        }

        if ($profileNames.Count -eq 0) {
            foreach ($prf in $AvailableTargets) {
                if (($null -ne $prf.Name) -and ($prf.Name -ne '') ) {
                    $profileNames.Add($prf.Name) | Out-Null
                    Write-Verbose -Message "[Get-AvailableProfiles] Adding $prf.Name"
                }
            }
        }
        Write-Verbose -Message "[Get-AvailableProfiles] Returning $($profileNames.Count) names."
     
    return $profileNames
}

function Get-Profiles {
    $availableProfiles.Clear()
    $availableProfiles = Get-AvailableProfiles
    Write-Information "`n#### Count: $($availableProfiles.Count)`n"

    if ($Verbose) {
        'Available Profiles'
        "------------------`n"
    }
    else {
        Write-Information "`n## Available Profiles`n"
    }

    $availableProfiles | ForEach-Object -Process { Write-Information "* $_" }

    if ($Verbose) {
        "`n---`n"
    }
    else {
        Write-Information ''
    }

    exit 0
}

function Invoke-Profile {
    param (
        [string]$ProfileName = $null,
        [string]$RootFolder = './test',
        [string]$Name = 'test',
        [switch]$Verbose = $false,
        [switch]$WhatIf = $false,
        [switch]$Force = $False,
        [switch]$Confirm = $False
    )

    if (($null -eq $ProfileName) -or ($ProfileName.Length -eq 0)) {
        Get-Profiles
    }

    try {
        [Config]$cfg = Initialize-RepoBuilder `
                        -ProfileName $ProfileName `
                        -RootFolder (Join-Path $RootFolder -ChildPath $ProfileName) `
                        -Name $Name `
                        -WhatIf:$WhatIf `
                        -Force:$Force `
                        -Confirm:$Confirm `
                        -Verbose:$Verbose

        $config=$cfg

        if ($Verbose) {
            '======================'
            'Parameters'
            '======================'
            $cfg.ToString()
            '======================'
        }

        if ((Test-Path $cfg.RootFolder) -and $cfg.Force) {
            Write-Information "``$($cfg.RootFolder)`` exists, it will be deleted first."
            $root = Get-Item $cfg.RootFolder -ErrorAction Stop
            $root | Remove-ItemSafely -Recurse -Force -Confirm:$cfg.Confirm
            if (Test-Path $root) {
                throw "$root was not deleted."
            }
        }

        $names = Get-AvailableProfiles;

        if ($names.Contains($profileName)) {
            $AvailableTargets = Get-AllTargets
            $selectedProfile = $AvailableTargets[$names.IndexOf($profileName)]
            $results = @()

            Write-Information "Using profile: $selectedProfile"

            [IEnumerator]$enumerator = $selectedProfile.SortedTargets().GetEnumerator()
            while ($enumerator.MoveNext()) {
                Set-Location $cfg.RootFolder

                [ActionScript]$target = $enumerator.Current
                $script = $target.Filename
                $function = $target.Function
                $script = Join-Path $PSScriptRoot -ChildPath $script
                if (Test-Path $script) {
                    Write-Verbose -Message '[Invoke-Profile] Loading ``$script``'
                    . $script
                    Write-Verbose -Message '[Invoke-Profile] Invoking ``$function``'
                    try {
                        $result = Exit-IfFails -ScriptBlock $function -Cfg $cfg
                        $results += "[$function]: Returned: $result"
                        Write-Information $result
                    }
                    catch {
                        $err = $_
                        $result += "[$function]: Error: $err"
                        Write-Error $err
                        Write-Error $err.ScriptStackTrace
                        throw $err
                    }
                    Write-Verbose -Message '[Invoke-Profile] ``$function`` completed'
                }
            }
        }
        else {
            Get-Profiles
        }
    }
    catch {
        $exitCode = $LASTEXITCODE
        $e = $_
        Write-Error $e
        Write-Error $e.ScriptStackTrace
    }
    finally {
        $root = $cfg.RootFolder
        if ($WhatIf -and (Test-Path $root)) {
            Write-Information "WhatIf: Removing ${root}"
            Get-Item $root -ErrorAction Stop `
            | Remove-ItemSafely -Recurse -Force -ErrorAction Stop | Out-Null
            Write-Information "WhatIf: Finished Removing ${root}: $(-not (Test-Path $root))"
        }
        else {
            Write-Information "Completed $($cfg.FinishedStages.Count) stages."
            # if($Verbose) {
            $cfg.FinishedStages | Format-Table -AutoSize
            # }
        }
    }

    ''
    exit $exitCode
}
