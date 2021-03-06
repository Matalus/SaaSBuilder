
##Auto-Generated using "PSProject Builder" Created by Matt Hamende 2018
#######################################################################
#Description: generates wireframe powershell projects
#Features:
## Define ScriptRoot
## Standard Function Libraries
## PSModule Prerequities Loader
## JSON Config File
########################################################################

#Set Default Error Handling - Set to Continue for Production
$ErrorActionPreference = "Stop"

#Generic Logging function --
Function Log($message, $color) {
    if ($color) {
        Write-Host -ForegroundColor $color "$(Get-Date -Format u) | $message"
    }
    else {
        "$(Get-Date -Format u) | $message"
    }
}

#Define Script Root for relative paths
$RunDir = split-path -parent $MyInvocation.MyCommand.Definition
Log "Setting Location to: $RunDir"
Set-Location $RunDir # Sets directory

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

#Load Config
Log "Loading Config"
#$Config = (Get-Content "$RunDir\config.json") -join "`n" | ConvertFrom-Json
$Config = (Get-Content $RunDir\config.yml) -join "`n" | ConvertFrom-Yaml #Converted to use YAML

#Load Prerequisites
Prereqs -config $Config

## Script Below this line #######################################################

<#
if ((Get-AzureSubscription) -eq $null) {
    $PubSettings = Get-ChildItem $RunDir -Filter "*.publishsettings"
    if ($PubSettings) {
        Log "Importing Publish Settings File"
        Import-AzurePublishSettingsFile -PublishSettingsFile $PubSettings.Name
    }
    else {
        Write-Error "Unable to Locate *.publishsettings file in the root dir"
    }
}
#>

$AzureSub = Get-AzureSubscription
if ($AzureSub -ne $null) {
    Log "Connected to Subscription"
    $AzureSub

}

Log "Setting Default Subscription"
$DefaultAzureSubParams = @{
    SubscriptionName = $Config.SubscriptionName
}
Select-AzureSubscription @DefaultAzureSubParams
$DefaultAzureSub = Get-AzureSubscription -Current

if ($DefaultAzureSub.SubscriptionName -eq $Config.SubscriptionName) {
    Log "Default Subscription Set to: $($DefaultAzureSub.SubscriptionName)"
}
Log "Logging in..."
#$Cred = Get-Credential
if(!$Cred){
    $Cred = Get-Credential -Message "Enter Azure Credentials"
}
Login-AzureRmAccount -Credential $Cred

$RGName = $Config.ResourceGroup.Name
$Location = $Config.ResourceGroup.DefaultLocation
Log "Validating Resource Groups" "Cyan"

$ResourceGroups = Get-AzureRmResourceGroup
$RGValid = $ResourceGroups | Where-Object {
    $_.ResourceGroupName -eq $RGName
}
if ($RGValid -ne $null) {
    Log " ~ Resource Group [$($RGName)] Already Exists..." "Green"
}
else {
    Log " + Creating Resource Group [$($RGName)]..."
    $RGParams = @{
        Name     = $RGName
        Location = $Location
    }

    $RG = New-AzureRmResourceGroup @RGParams
}

$NSG_Name = $Config.ResourceGroup.Name + "-NSG"
Log "Validating Network Security Group [$($NSG_Name)].." "Cyan"
$NSG = Get-AzureRmNetworkSecurityGroup | Where-Object {
    $_.Name -eq $NSG_Name
}
if($NSG -ne $null){
    Log " ~ Network Security Group [$($NSG_Name)] Already Exists" "Green"
}else{
    Log " + Creating Network Security Group [$($NSG_Name)]" "Yellow"
    $NSG_Params = @{
        Name = $NSG_Name
        ResourceGroupName = $Config.ResourceGroup.Name
        Location = $Config.ResourceGroup.DefaultLocation
    }
    $NSG = New-AzureRmNetworkSecurityGroup @NSG_Params
}

Log "Validating Network Security Group Rules..." "Cyan"

[array]$NSG_Rules = Get-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $NSG

$rules_missing = 0
ForEach($rule in $Config.ResourceGroup.NSG_Rules){
    $NSG_Rule_Match = $NSG_Rules | Where-Object {
        $_.Name -eq $rule.Name -and
        $_.Priority -eq $rule.Pri -and
        $_.DestinationPortRange -eq $rule.PortRange
    }
    if($NSG_Rule_Match){
        Log " ~ Rule: $($rule.Name) : $($rule.Direction) : $($rule.Pri)  $($rule.Protocol) $($rule.PortRange) - Already Exists" "Green"
    }else{
        $rules_missing++
        Log " + Creating Rule: $($rule.Name) : $($rule.Direction) : $($rule.Pri)  $($rule.Protocol) $($rule.PortRange)..." "Yellow"
        $RuleParams = @{
            Name = $Rule.Name
            Description = $Rule.Name
            Access = "Allow"
            Protocol = $Rule.Protocol
            Direction = $Rule.Direction
            Priority = $Rule.Pri
            SourcePortRange = "*"
            SourceAddressPrefix = "*"
            DestinationPortRange = $Rule.PortRange
            DestinationAddressPrefix = "*"
            NetworkSecurityGroup = $NSG
        }
        $RuleAdd = Add-AzureRmNetworkSecurityRuleConfig @RuleParams
    }
    
}

if($NSG.SecurityRules.Count -ge 1 -and $rules_missing -ge 1){
    Log "Updating Security Rules on [$($NSG_Name)]" "Magenta"
    $NSG = Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $NSG
}

$NSG.SecurityRules | Format-Table Name,Access,Priority,Protocol,Direction,DestinationPortRange

Log "Validating Database Resources" "Cyan"

$SQLServers = $null
$SQLServers = Get-AzureRmSqlServer -ResourceGroupName $RGName
$SQLValid = $null
$SQLServerName = $Config.ResourceGroup.Name.ToLower() + "-sql-01"
$SQLValid = $SQLServers | Where-Object {
    $_.ServerName -eq $SQLServerName -and
    $_.ResourceGroupName -eq $RGName
}
if ($SQLValid) {
    Log " ~ SQL Server [ $SQLServerName ] already exists" "Green"
}
else {
    Log " + Creating SQL Server [ $SQLServerName ]"
    $SQLAdminCreds = New-Object System.Management.Automation.PSCredential(
        $Config.SQL.SAUser,
        ($Config.SQL.SAPass | ConvertTo-SecureString -AsPlainText -Force)
    )
    
    $SQLServerParams = @{
        ResourceGroupName           = $RGName
        ServerName                  = $SQLServerName
        Location                    = $Location
        SQLAdministratorCredentials = $SQLAdminCreds
    }
    $SQLValid = New-AzureRmSqlServer @SQLServerParams
}


Log "Validating SQL Database" "Cyan"
$SQLDBName = $Config.ResourceGroup.Name.ToLower() + "-central"
$GetSQLDBParams = @{
    ResourceGroupName = $RGName
    ServerName        = $SQLServerName
}
$SQLDB = Get-AzureRmSqlDatabase @GetSQLDBParams

$SQLDB_Valid = $SQLDB | Where-Object {
    $_.DatabaseName -eq $SQLDBName
}
if ($SQLDB_Valid) {
    Log " ~ Database [ $SQLDBName ] already exists" "Green"
}
else {
    Log " + Creating Database [ $SQLDBName ]"
    $CreateDBParams = @{
        ResourceGroupName             = $RGName
        ServerName                    = $SQLServerName
        DatabaseName                  = $SQLDBName
        CollationName                 = $Config.SQL.Collation
        RequestedServiceObjectiveName = $Config.SQL.PricingTier
    }
    $SQLDB_Valid = New-AzureRmSqlDatabase @CreateDBParams
}

Log "Configuring Connection Params" "Magenta"

$dbconfig = @{
    ServerInstance = $SQLValid.FullyQualifiedDomainName
    Database       = $SQLDBName
    User           = $COnfig.SQL.SAUser
    Pass           = $COnfig.SQL.SAPass
}

Log "Validating SQL Firewall Rules" "Cyan"
$GetFWRulesParams = @{
    ResourceGroupName = $RGName
    ServerName        = $SQLServerName
}

$FWRules = Get-AzureRmSqlServerFirewallRule @GetFWRulesParams

$GetIPUrl = "http://ipinfo.io/json"
$WorkStationIP = (Invoke-WebRequest -Uri $GetIPUrl).Content | ConvertFrom-Json

#This Firewall rule allows all Azure Services to talk to each other
$AllowRuleParams = [PSCustomObject]@{
    Name    = "AllowAllAzureIPs"
    StartIP = "0.0.0.0"
    EndIP   = "0.0.0.0"
}
#Add Rule to Default Evalutation Array
if ($AllowRuleParams.Name -notin $Config.SQL.FireWall.Name) {
    $Config.SQL.FireWall += $AllowRuleParams
}
 
#This Firewall rule adds your public IP to the default ruleset
$defaultRule = [PSCustomObject]@{
    Name    = "$($WorkStationIP.city):$($ENV:USERNAME):$($ENV:COMPUTERNAME):$($WorkStationIP.ip)"
    StartIP = $WorkStationIP.ip
    EndIP   = $WorkStationIP.ip
}
#Add Rule to Default Evaluation Array
if ($defaultRule.Name -notin $Config.SQL.FireWall.Name) {
    $Config.SQL.FireWall += $defaultRule
}

#Evaluate all rules from JSON and default ruleset
ForEach ($Rule in $Config.SQL.FireWall) {
    $RuleValid = $FWRules | Where-Object {
        $_.FireWallRulename -eq $Rule.Name -and
        $_.StartIPAddress -eq $Rule.StartIP -and
        $_.EndIPAddress -eq $Rule.EndIP
    }
    if ($RuleValid) {
        Log " ~ Rule: [$($Rule.Name)] already exists..." "Green"
    }
    else {
        Log " + Creating Rule [$($Rule.Name)]"
        $RuleParams = @{
            ResourceGroupName = $RGName
            ServerName        = $SQLServerName
            FireWallRulename  = $Rule.name
            StartIPAddress    = $Rule.StartIP
            EndIPAddress      = $Rule.EndIP
        }
        $newRule = New-AzureRmSqlServerFirewallRule @RuleParams
    }
}

Log " <-> Testing SQL Server Connection..." "Magenta"
Log " ~ ServerInstance: $($dbconfig.ServerInstance)" "Magenta"
$SQLTest = SQLQuery -query "SELECT database_id,name,collation_name,create_date FROM sys.databases" -dbconfig  $dbconfig

if ($SQLTest.name -contains $SQLDBName) {
    Write-Host -ForegroundColor Green " + Success"
    $SQLTest | Format-Table  
}
Log "Validating Storage Account" "Cyan"

$StorAccount = Get-AzureRmStorageAccount

$StorAccName = $Config.ResourceGroup.Name.ToLower() -replace '[^a-zA-Z0-9]', ''
$StorAcc_Valid = $StorAccount | Where-Object {
    $_.ResourceGroupName -eq $RGName -and
    $_.StorageAccountName -eq $StorAccName
}

if ($StorAcc_Valid) {
    Log " ~ Storage Account: [ $StorAccNAme ] Already Exists " "Green"
}
else {
    Log " + Creating Storage Account: [ $StorAccNAme ]"
    $StorAccParams = @{
        Name              = $StorAccName
        ResourceGroupName = $RGName
        Type              = $Config.StorageAccount.Type
        Location          = $Location
    }
    $StorAcc_Valid = New-AzureRmStorageAccount @StorAccParams
}

Log "Validating Application Server" "Cyan"

$VMName = $Config.ResourceGroup.Name.ToLower() + "-web-01"

if ($VMName.Length -gt 15) {
    Write-Error "VM Name cannot be longer than 15 chars ($($VMname.length))"
}

$VM = Get-AzureRMVM
$VM_Valid = $VM | Where-Object {
    $_.ResourceGroupName -eq $RGName -and
    $_.Name -eq $VMName
}

if ($VM_Valid) {
    Log " ~ Server [$($VM_Valid.Name)] already exists" "Green"
}
else {
    Log "Configuring Virtual Machine [$($VMName)]..." "Magenta"
    Log " + Creating VM Credentials..." "Yellow"
    $VMCred = New-Object System.Management.Automation.PSCredential(
        $Config.AppServer.User,
        ($Config.AppServer.Pass | ConvertTo-SecureString -AsPlainText -Force)
    )
    Log " + Creating VM Config..." "Yellow"
    $VMConfigParams = @{
        VMName = $VMName
        VMSize = $COnfig.AppServer.Size
    }
    $VMConfig = New-AzureRmVMConfig @VMConfigParams
    Log " + Setting Subnet"
    $SubnetParams = @{
        AddressPrefix = $Config.AppServer.CIDR
        Name          = $RGName + "-SUBNET"
    }
    $Subnet = New-AzureRmVirtualNetworkSubnetConfig @SubnetParams

    Log " + Setting Virtual Network"
    $VNParams = @{
        ResourceGroupName = $RGName
        Location          = $Location
        Name              = $RGName + "-VNET"
        AddressPrefix     = $Config.ResourceGroup.CIDR
        Subnet            = $Subnet
        Force             = $true
    }
    $VNET = New-AzureRmVirtualNetwork @VNParams

    Log " + Setting Public IP"
    $IPName = $RGName + "-PublicIP"
    $IpParams = @{
        ResourceGroupName = $RGName
        Location          = $Location
        Name              = $IPName
        AllocationMethod  = "Static"
        DomainNameLabel   = $VMName.ToLower()
        Force             = $true
    }
    $PublicIP = $null
 
    $PublicIP = Get-AzureRmPublicIpAddress | Where-Object {
        $_.ResourceGroupName -eq $RGName -and
        $_.Name -eq $IPName
    }
    if ($PublicIP) {
        Log " ~ IP [$IPName] already exists" "Green"
    }
    else {
        Log " + Creating Public IP..." "Yellow"
        $PublicIP = New-AzureRmPublicIpAddress @IpParams
    }

    Log "Validating Network Interface" "Cyan"
    $nicname = $VMName.ToLower() + "-nic"
    $Int = Get-AzureRmNetworkInterface
    $Int_Valid = $Int | Where-Object {
        $_.name -eq $nicname -and 
        $_.ResourceGroupName -eq $RGName
    }
    if ($Int_Valid) {
        Log " ~ Network Interface: [ $nicname ] Already Exists" "Green"
    }
    else {
        Log " + Creating Network Interface: [ $nicname ] " "Yellow"
        $IntParams = @{
            Name              = $nicname
            ResourceGroupName = $RGName
            Location          = $Location
            SubnetID          = $VNET.Subnets[0].Id
            PublicIpAddressId = $PublicIP.ID
        }
        $Int_Valid = New-AzureRmNetworkInterface @IntParams
    }


    $VMConfig | Add-AzureRmVMNetworkInterface -Id $Int_Valid.ID | Out-Null
    <#  
    Log "Setting VNIC"
    $VNICParams = @{
        ResourceGroupName = $RGName
        Location          = $Location
        Name              = $VMName + "-VNIC"
        SubnetID          = $SubnetID
    }
#>
    Log " + Setting OS Type [$($Config.AppServer.OS)]"
    $OSParams = @{
        Windows      = $true
        ComputerName = $VMName
        Credential   = $VMCred
    }
    $VMConfig | Set-AzureRmVMOperatingSystem @OSParams | Out-Null
    Log " + Setting OS Image [$($Config.AppServer.Image)]"
    $ImageParams = @{
        PublisherName = $Config.AppServer.Publisher
        Offer         = $Config.AppServer.Offer
        Skus          = $Config.AppServer.Image
        Version       = $Config.AppServer.Version
    }
    $VMConfig | Set-AzureRmVMSourceImage @ImageParams | Out-Null

    Log " + Setting OS Disk"
    $DiskParams = @{
        name         = $VMName + "_osDisk"
        CreateOption = "fromImage"
        Caching      = "ReadWrite"
        VhdUri       = $StorAcc_Valid.PrimaryEndpoints.Blob.ToString() + "vhds/" + $VMName + ".vhd"
        
    }
    $VMConfig | Set-AzureRmVMOSDisk @DiskParams | Out-Null
    $VMParams = @{
        ResourceGroupName = $RGName
        Location          = $Location
        VM                = $VMConfig
    }
    #TODO Virtual Network
    Log " + Creating Virtual Machine [ $($VMParams.VM.Name) ] using New-AzureRmVM..."
    $newVM = New-AzureRmVM @VMParams
}

if ($Config.ApplicationGateway.Enabled -eq $True) {
    Log "Validating Application Gateway" "Cyan"
    $AG_name = $RGName + "-AG"
    $AG_Valid = Get-AzureRmApplicationGateway | Where-Object {
        $_.name -eq $($AG_name)
    }
    if ($AG_Valid) {
        Log " ~ Application Gateway: [ $AG_Name ] Already Exists" "Green"
    }
    else {
        Log " + Creating Application Gateway: [ $AG_Name ]"
        Log " + Setting Backend Subnet Config"
        $BackEndSubnetParams = @{
            Name          = $RGName + "-BACKEND-SUBNET"
            AddressPrefix = $Config.ApplicationGateway.BackEndPrefix
        }
        $BackEndSubnet = New-AzureRmVirtualNetworkSubnetConfig @BackEndSubnetParams

        Log " + Setting AG Subnet Config"
        $AGSubnetParams = @{
            Name          = $RGName + "-AG-SUBNET"
            AddressPrefix = $COnfig.ApplicationGateway.AGPrefix
        }
        $AGSubnet = New-AzureRmVirtualNetworkSubnetConfig @AGSubnetParams

        Log " + Setting AG Virtual Network"
        $AGVNET_Valid = Get-AzureRmVirtualNetwork | Where-Object {
            $_.name -eq $RGName + "-AG-VNET" -and
            $_.ResourceGroupName -eq $RGName
        }
        if ($AGVNET_Valid) {
            # AG VNET already exists
        }
        else {
            $AGVNETParams = @{
                ResourceGroupName = $RGName
                Location          = $Location
                Name              = $RGName + "-AG-VNET"
            }
            $AGVNET = New-AzureRmVirtualNetwork @AGVNETParams
        }

        Log " + Setting AG Public IP"
        $AGPublicIP = Get-AzureRmPublicIpAddress | Where-Object {
            $_.name -eq $RGName + "-AG-PublicIP" -and
            $_.ResourceGroupName -eq $RGName
        }
        if ($AGPublicIP) {
            # AG Public IP Already Exists
        }
        else {
            $AGPublicIPParams = @{
                ResourceGroupName = $RGName
                Location          = $Location
                Name              = $RGName + "-AG-PublicIP"
                AllocationMethod  = "Dynamic"
            }
            $AGPublicIP = New-AzureRmPublicIpAddress @AGPublicIPParams
        }

        Log " + Creating Application Gateway: [ $AG_Name ]" "Yellow"
        $AGSkuParams = @{
            Name     = $Config.ApplicationGateway.Sku
            Tier     = $Config.ApplicationGateway.Tier
            Capacity = $Config.ApplicationGateway.Capacity
        }
        $AGSku = New-AzureRmApplicationGatewaySku @AGSkuParams
    
        $AGParams = @{
            Name                    = $AG_name
            ResourceGroupName       = $RGName
            Location                = $Location
            SKu                     = $AGSku
            FrontEndIPConfiguration = $AGPublicIP.ID
        }

        $AG = New-AzureApplicationGateway @AGParams
    }
} #End Application Gateway Setup - Enabled must be true in JSON to build

Log "Validating Database Status" "Cyan"
$TableQuery = "SELECT * FROM INFORMATION_SCHEMA.TABLES"
[array]$DBTables = SQLQuery -dbconfig $dbconfig -query $TableQuery

$SQLDir = $COnfig.SQL.ScriptsDir
$SqlError = 0
if ($Config.SQL.RunBuildScripts -eq $true) {
    $initScript = Get-ChildItem $SQLDir -Filter "000*"

    if ($Config.SQL.initScriptComplete -eq $false) {
        Log "Running Init Script on Master : $($initScript.Name)"
        $masterconfig = @{
            ServerInstance = $SQLValid.FullyQualifiedDomainName
            Database       = "master"
            User           = $COnfig.SQL.SAUser
            Pass           = $COnfig.SQL.SAPass
        }
        $Query = [System.IO.File]::ReadAllText($initScript.FullName).Replace('YOURDATABASENAMEHERE',$SQLDBName)
        Try {
            $RunInit = SQLQuery -dbconfig $masterconfig -query $Query -Verbose $true
        }
        Catch {
            Write-Error $_
            $InitError++
        }

        if ($InitError -ge 1) {
            Write-Error "Failed: Init Script Failed"
        }
        else {
            Write-Host -ForegroundColor Green " + Success"
            $Config.SQL.initScriptComplete = $true
            $Config | ConvertTo-Json -Depth 50 | Format-Json | Out-File "$RunDir\config.json" -Force
        }
    }
    else {
        Log " ~ Init Script Already Ran" "Green"
    }
    Log "Getting Build Scripts"
    if ($Config.SQL.ScriptsDir -and (Test-Path $Config.SQL.ScriptsDir)) {
    
        $SQLScripts = Get-ChildItem $SQLDir -Filter "*.SQL" | Where-Object {
            $_.name -ne $initScript.name
        } | Sort-Object Name
    }
    else {
        Write-Error "Unable to find ScriptsDir"
    }

    if ($SQLScripts) {

        if ($Config.SQL.LastScriptComplete -eq $null) {
            $ScriptIndex = 0
        }
        else {
            $LastScript = $SQLScripts | Where-Object {
                $_.name -eq $Config.SQL.LastScriptComplete
            }
            $ScriptIndex = $SQLScripts.indexOf($LastScript) + 1
        }

        $Count = 0
        While ($ScriptIndex -lt $SQLScripts.Length) {
            $Count++
            $CurrentScript = $SQLScripts[$ScriptIndex]
            Log "Running Build Script: ($($ScriptIndex + 1)\$($SQLScripts.Count)) [ $($CurrentScript.name) ]"
            " + Batching Script"
            #$separator = [string[]]@("GO\n")
            $separator = '^(?:\bGO\b\r)'
            [array]$BatchSeparated = ( [system.io.file]::ReadAllText( $CurrentScript.FullName ) -csplit $separator,"999999","multiline" )
            
            $BatchCount = 0
            $Error.Clear()
            ForEach ($batch in $BatchSeparated) {
                $BatchCount++
                $WriteParams = @{
                    Activity = "Batch: $BatchCount/$($BatchSeparated.count) | Script: $($ScriptIndex + 1)/$($SqlScripts.Count) | $($CurrentScript.Name)"
                    PercentComplete = ($BatchCount / $BatchSeparated.Count) * 100
                    ShowPercent = $true
                    ActivityPadding = 100
                }
                WriteInlineProgress @WriteParams

                Try {
                    #Write-Host $batch
                    SQLQuery -dbconfig $dbconfig -query $batch
                }
                Catch {
                    Write-Error $_
                }
                #Write-Host -ForegroundColor Magenta "Batch: $BatchCount / $($BatchSeparated.count) | Script: $($ScriptIndex + 1) / $($SqlScripts.Count) | $($CurrentScript.Name)"
            }

            $ScriptIndex++
            $Config.SQL.LastScriptComplete = $CurrentScript.name
            $Config | ConvertTo-Json -Depth 50 | Format-Json | Out-File "$RunDir\config.json" -Force
            $Config | ConvertTo-Yaml | Out-File "$RunDir\config.yml" -Force
        }
        if ($SqlError -eq 0) {
            $Config.SQL.RunBuildScripts = $false
            $Config | ConvertTo-Json -Depth 50 | Format-Json | Out-File "$RunDir\config.json" -Force
            $Config | ConvertTo-Yaml | Out-File "$RunDir\config.yml" -Force
            ""
            Log "ALL BUILDS SCRIPTS COMPLETE" "Green"
        }
    }
}
else {
    Log " ~ All Build Scripts Completed Previously - Adjust Configuration to Run Again" "Green"
}

Log "Validating Change Sets" "Cyan"
if($Config.SQL.RunChangeSets -eq $true){
    Log "Getting Max Change Set" "Yellow"

    $MaxCS = SQLQuery -dbconfig $dbconfig -query "SELECT max(change_id) FROM db_changes"

    $ChangeSets = Get-ChildItem $Config.SQL.ChangeSets | Sort-Object Name
    $MaxBuild = ([version]$MaxCS.Column1).Build

    $CSToApply = $ChangeSets | Where-Object {([version]$_.BaseName).Build -gt $MaxBuild}

    if ($Config.SQl.RunChangeSets -eq $true) {
        $ChangeCount = 0
        $SqlError = 0
        ForEach ($change in $CSToApply) {
            $ChangeCount++
            Try {
                Write-Host "Running Change Set: ($ChangeCount \ $($CSToApply.Count)) $($Change.Name)"
                $SQL = SQLQuery -dbconfig $dbconfig -inputfile $Change.FullName #-Verbose $true
            }
            Catch {$SqlError++}
            Write-Host -ForegroundColor Magenta "Error Count : $SQLError | Change Set: $ChangeCount \ $($CSToApply.Count) | $($Change.Name)"
        }
        Log "All Change Sets Completed!"
        $Config.SQL.RunChangeSets = $false
        $Config | ConvertTo-Json -Depth 50 | Format-Json | Out-File "$RunDir\config.json" -Force
        $Config | ConvertTo-Yaml | Out-File "$RunDir\config.yml" -Force
    }
}else{
    Log " ~ All Change Sets completed previously" "Green"
}

""
Write-Host -ForegroundColor Green "######################################################"
Log  "ALL BUILDS STEPS COMPLETE" "White"
Write-Host -ForegroundColor Green "######################################################"
