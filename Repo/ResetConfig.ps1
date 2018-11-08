# Resets Provisioning State for Config.json

#Define script dir
$RunDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

#Imports Function Library
Log "Importing Modules"
Try {
    Remove-Module Functions -ErrorAction SilentlyContinue
}
Catch {}
Try {
    Import-Module "$RunDir\Modules\Functions.psm1" -DisableNameChecking -ErrorAction SilentlyContinue
}
Catch { $_ }

$jsonfile = "$RunDir\config.json"

if(!(test-path $jsonfile)){
   Write-Error "Unable to locate JSON config at: $jsonfile"
}
#Import Config
$JSON = (Get-Content "$RunDir\config.json") -join "`n" | ConvertFrom-Json

"Resetting InitScriptComplete"
$JSON.SQL.initScriptComplete = $false
"Resetting LastScriptComplete"
$JSON.SQL.LastScriptComplete = $null
"Resetting RunChangeSets"
$JSON.SQL.RunChangeSets = $true
"Resetting RunBuildScripts"
$JSON.SQL.RunBuildScripts = $true

$JSON | ConvertTo-Json -Depth 50 | Format-Json | Out-File -FilePath $jsonfile -Force