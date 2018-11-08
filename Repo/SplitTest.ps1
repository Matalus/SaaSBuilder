$SQLDir = 'C:\svn\io_software\Releases\branches\3.7\DatabaseObjects\AzureInstallation\SQLAzureSteps\NewAzureSqlInstall'
$Scripts = Get-ChildItem $SQLDir
$Script = $Scripts[1]

[array]$SeparatedBatch = ( [system.io.file]::ReadAllText( $Script.FullName ) -split '(?:\bGO\b)' ) | ForEach-Object { $_ + '`r`nGO' }
$SeparatedBatch[0]
'###########################################################################################'
$SeparatedBatch[1]
'###########################################################################################'
$SeparatedBatch[2]

"Array Count: $($SeparatedBatch.Count)"

