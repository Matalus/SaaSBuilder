

Function GetAzureMetric($RG, $Name, $Metric) {
    $GetResourceParams = @{
        Name              = $Name
        ResourceGroupName = $RG
    }
    $Resource = Get-AzureRmResource @GetResourceParams

    $MonitorParameters = @{
        ResourceId  = ($Resource.ResourceId)
        MetricNames = $Metric
        StartTime   = (Get-Date).AddMinutes(-1)
        EndTime     = Get-Date
        #DetailedOutput = $true
    }
    Try {
        $Metric = (Get-AzureRmMetric @MonitorParameters).Data
    }
    Catch {
        $_
    }
    $Metric[0].Average
}


$params = @{
    Name   = "blrs-sba-sql-01"
    RG     = "BLRS-SBA"
    Metric = "dtu_used"
}
GetAzureMetric @params

