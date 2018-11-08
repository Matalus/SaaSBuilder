#This Script sanitizes saved credential information for public upload
$ErrorActionPreference = "stop"

#Define Root Path
$RunDir = split-path -parent $MyInvocation.MyCommand.Definition
$SourceDir = $RunDir
$RepoDir = "$RunDir\Repo"
$filters = @("SubscriptionName","SAUser","SAPass","User","Pass","ChangeSets","ScriptsDir","LastScriptComplete","Database","ServerName","RGName")

Function Log($message) {
    "$(Get-Date -Format u) | $message"
}

if(!(Test-Path $RepoDir)){
    Log "Creating Repo Directory..."
    New-Item -Path $RepoDir -ItemType Directory -ErrorAction SilentlyContinue
}


Log "Compiling functions..."
Try{
Remove-Module JSON_Sanitize -ErrorAction SilentlyContinue
}Catch{$_ | Out-Null}

Import-Module "$RunDir\JSON_Sanitize.psm1" -ErrorAction SilentlyContinue
 
Log "Getting Current Repo Files..."
$RepoFiles = Get-ChildItem $RepoDir -Recurse | Where-Object{
    $_.PsIsContainer -eq $False
}
$RepoDirs = Get-ChildItem $RepoDir -Recurse | Where-Object{
    $_.PsIsContainer -eq $true
}

Log "Found: $($RepoFiles.Count) files in $($RepoDirs.Count) directories"

Log "Cleaning Repo Folder..."
Get-ChildItem $RepoDir -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -Confirm:$false

Log "Updating Repo Files..."
$exclude = @("Repo")
$excludeMatch = @("csv","xlsx","Repo")
[regex] $excludeMatchRegEx = '(?i)' + (($excludeMatch |ForEach-Object {[regex]::escape($_)}) -join "|") + ""
Get-ChildItem -Path $SourceDir -Recurse -Exclude $exclude | 
 Where-Object { $excludeMatch -eq $null -or $_.FullName.Replace($SourceDir, "") -notmatch $excludeMatchRegEx} |
 Copy-Item -Destination {
  if ($_.PSIsContainer) {
   Join-Path $RepoDir $_.Parent.FullName.Substring($SourceDir.length)
  } else {
   Join-Path $RepoDir $_.FullName.Substring($SourceDir.length)
  }
 } -Force -Exclude $exclude

Log "Collecting Config Files..."
$ConfigFiles = Get-ChildItem $RepoDir -Recurse | Where-Object {
    $_.name -like "*.json"
}

ForEach($file in $ConfigFiles | Where-Object{$_.FullName -notlike "*.vs*"}){
    Log "Sanitizing File: $($file.FullName)"
    $content = (Get-Content $file.FullName) -join "`n" | ConvertFrom-Json

    $ObjProps = Get-Properties -Object $content -PathName '$content'

    $output = Sanitize-Object -object $ObjProps -propsarray $filters -varname 'content' -fullobject $content 
    if($output.SQL.Firewall){
        $output.SQL.Firewall = @()
    }
    $output | ConvertTo-Json -Depth 50 | Format-JSON | Set-Content $file.FullName -Force
    $output | ConvertTo-Yaml | Set-Content $file.FullName.Replace("json","yml") -Force
}

Log "GitPrep Complete"

Try{
    $notepath = "$RepoDir\If you can see this file it' safe to upload.txt"
    New-Item -ItemType File -Path $notepath -Force
    "Only the files in the repo directory are safe to upload, files in the root may contain sensitive information" | Set-Content -Path $notepath -Force
    Invoke-Item $RepoDir
}catch{$_ | Out-Null}
