function Initialize-Git([Config]$cfg) {
    if ($cfg.AddGit) {
        $command = $cfg.GitCommand
        $source = $command.Source
        Push-Location | Out-Null
        try {
            $invocation = $MyInvocation.MyCommand
            Write-Verbose -Verbose:$cfg.Verbose -Message "[$invocation] Entered"
            Set-RootLocation

            if ($null -eq $source) {
                Write-Verbose -Verbose:$cfg.Verbose -Message "[$invocation] [`$source] is `$null"
                Exit-IfFails -ScriptBlock { & winget install 'git.git' }

                $cfg.GitCommand = (Get-Command git)
                $command = $cfg.GitCommand
                $source = $command.Source
            }
            else {
                Write-Verbose -Verbose:$cfg.Verbose -Message "[$invocation] [`$command.Source] is [$command][$source]"
            }

            Write-Verbose -Verbose:$cfg.Verbose -Message "[$invocation] Exit-IfFails -ScriptBlock { & $source init }"
            Exit-IfFails -ScriptBlock { & $source init }

            if (-not (Test-Path '.gitignore')) {
                $command = $cfg.GitignoreCommand
                $source = $command.Source
                if ($null -eq $source) {
                    Exit-IfFails -ScriptBlock { & $cfg.DotnetCommand tool install dotnet-gitignore -g }
                    $cfg.GitignoreCommand = (Get-Command dotnet-gitignore)
                }

                $command = $cfg.GitignoreCommand
                $source = $command.Source
                if ($null -ne $source) {
                    Exit-IfFails -ScriptBlock { & $cfg.GitignoreCommand }
                }
            }
        }
        catch {
            $exitCode = $LASTEXITCODE
            $e = $_
            Write-Error $e
            Write-Error $e.ScriptStackTrace
            exit $exitCode
        }
        finally {
            Pop-Location -Verbose:$cfg.Verbose | Out-Null
        }
    }
}
