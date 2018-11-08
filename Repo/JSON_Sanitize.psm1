﻿#function to parse psobject and map out object tree and paths
function Get-Properties($Object, $MaxLevels="5", $PathName, $Level=0){
    if ($Level -eq 0) { 
        $oldErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
    }
    $props = @()
    $rootProps = $Object | Get-Member -ErrorAction SilentlyContinue | Where-Object { $_.MemberType -match "Property"} 
    $rootProps | ForEach-Object { $props += "$PathName.$($_.Name)" }
    if ($Level -lt $MaxLevels){
        $typesToExclude = "System.Boolean", "System.String", "System.Int32", "System.Char"
        $props += $rootProps | ForEach-Object {
                    $propName = $_.Name;
                    $obj = $($Object.$propName)
                    $type = ($obj.GetType()).ToString()
                    if (!($typesToExclude.Contains($type) ) ){
                        $childPathName = "$PathName.$propName"
                        if ($obj -ne $null) {
                            Get-Properties -Object $obj -PathName $childPathName -Level ($Level + 1) -MaxLevels $MaxLevels }
                        }
                    }
    }
    if ($Level -eq 0) {$ErrorActionPreference = $oldErrorPreference}
    $props
}

Export-ModuleMember Get-Properties

#function that applies filters to psobject paths and nulls values in filters array
Function Sanitize-Object($object,$propsarray,$varname,$fullobject){
    $count = 0
    New-Variable -Name $varname -Value $fullobject
    ForEach($propfilter in $propsarray){
       $props = $object | Where-Object{ $_ -like "*$propfilter" }
       ForEach($path in $props){
            [string]$pathstring = $path.Replace('$','')
            $count++
            $splitpath = $path.Split(".")
            $propname = $splitpath[$($splitpath.length -1)]
            $rootpath = $path.Replace(".$propname","")
            $invoke = Invoke-Expression -command $path
            if($invoke){
                $invokecount = 0
                ForEach($item in $invoke){                
                    $invokepath = "$rootpath[$invokecount].$propname"
                    if($item){
                        #Write-Host -ForegroundColor Yellow "   + enum $invokecount : value is not null: $item"
                        $nullcmd = $invokepath + ' = $null'
                        Try{
                        Invoke-Expression -command $nullcmd
                        }Catch{
                            $_ | Out-Null
                        }
                        if((Invoke-Expression -command $Invokepath) -eq $null){
                            #Write-Host -ForegroundColor White "      + value is null; value= $(Invoke-Expression -command $Invokepath)"
                        }else{
                            #Write-Host -ForegroundColor Red "      + value is not null; value = $(Invoke-Expression -command $Invokepath)"
                        }
                    }else{
                        #write-host -ForegroundColor Cyan "   + enum $invokecount : value is already null"
                    }
                    $invokecount++  
                }
            }else{
                #Write-Host -ForegroundColor White "   +   Path: $pathstring is null"
            }
        }    
    }
    (Get-Variable -Name $varname).Value
}

Export-ModuleMember Sanitize-Object

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split '\n' |
      % {
        if ($_ -match '[\}\]]') {
          # This line contains  ] or }, decrement the indentation level
          $indent--
        }
        $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
        if ($_ -match '[\{\[]') {
          # This line contains [ or {, increment the indentation level
          $indent++
        }
        $line
    }) -Join "`n"
  }

  Export-ModuleMember Format-Json

