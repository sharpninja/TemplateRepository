
function Initialize-GitHubWorkflow([Config]$cfg) {
    Push-Location
    try {
        $invocation = $MyInvocation.MyCommand
        Write-Verbose -Verbose:$cfg.Verbose -Message "[$invocation] Entered"
        Set-RootLocation
        . ./Git.ps1
        Invoke-Dependency -Target Initialize-Git -Caller $invocation

        $newItem = New-Item '.github/Workflows' -ItemType Directory -Force -Verbose:$cfg.Verbose

        Write-Information "Created Github Workflows Folder: [$newItem]"
    }
    catch {
        $exitCode = $LASTEXITCODE
        $e = $_
        Write-Error $e
        Write-Error $e.ScriptStackTrace
        Write-Error [System.String]::Format($FailureMessage, $exitCode, $script)
        exit $exitCode
    }
    finally {
        Pop-Location | Out-Null
    }
}
