# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$schemaId = $Request.Body."schemaId"
$monitorCondition = $Request.Body."data"."essentials"."monitorCondition"

if ($schemaId -notlike "azureMonitorCommonAlertSchema") {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = "Invalid schema id $schemaId, it must be azureMonitorCommonAlertSchema."
    })
}
elseif ($monitorCondition -notlike "Fired") {
    $skipMsg = "Skipping execution because received an alert notification with monitor condition $monitorCondition, while the only valid condition to be process is Fired"
    Write-Information($skipMsg)
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Ok
        Body = $skipMsg
    })    
}
else {
    # Write to the Azure Functions log stream.
    Write-Information("PowerShell Cosmos DB automation function processing alert {0} with severity {1}" `
        -f  $Request.Body."data"."essentials"."alertRule", `
            $Request.Body."data"."essentials"."severity")

    # resource id format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/{resourceProviderNamespace}/{resourceType}/{resourceName} .For more information https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-functions-resource#return-value-4
    $resourceId = $Request.Body."data"."essentials"."alertTargetIDs".Split("/")

    For ($i=0; $i -lt $resourceId.Length; $i++) {
        switch ( $resourceId[$i] )
        {
            ResourceGroups
            {
                $resourceGroupNameResourceId = $resourceId[$i+1]
            }
            DatabaseAccounts
            {
                $accountNameResourceId = $resourceId[$i+1]
            }
        }
    }

    $resourceGroupName = $env:CosmosDbResourceGroup
    $accountName = $env:CosmosDbAccountName
    $databaseName = $env:CosmosDbDatabaseName
    $containerName = $env:CosmosDbContainterName
    $containerResourceName = $accountName + "/sql/" + $databaseName + "/" + $containerName + "/throughput"
    $throughput = $env:CosmosDbRUs

    try {
        if($resourceGroupName -notlike $resourceGroupNameResourceId)
        {
            $errMsg="Invalid Alert Resource Group. Expected alert for resource group $resourceGroupName and received $resourceGroupNameResourceId. Review the Azure Metric Alert and action group configuration."
            Write-Error($errMsg)
            
            $status = [HttpStatusCode]::InternalServerError
            $body = $errMsg
        }
        elseif ($accountName -notlike $accountNameResourceId) {
            $errMsg="Invalid Alert Cosmos Db Account. Expected alert for cosmos db account $accountName and received $accountNameResourceId. Review the Azure Metric Alert and action group configuration."
            Write-Error($errMsg)
            
            $status = [HttpStatusCode]::InternalServerError
            $body = $errMsg
        }
        else {
            Write-Information("Attempting to provision $throughput RUs to $containerResourceName")

            $resType = "Microsoft.DocumentDb/databaseAccounts/apis/databases/containers/settings"
            $apiVersion = "2015-04-08"
        
            $properties = @{
                "resource"=@{"throughput"=$throughput}
            }
                
            Set-AzResource -ResourceType $resType `
            -ApiVersion $apiVersion -ResourceGroupName $resourceGroupName `
            -Name $containerResourceName -PropertyObject $properties `
            -Force -ErrorAction Stop;
    
            $status = [HttpStatusCode]::OK
            $body = "Successfully provisioned $throughput resources units for $containerResourceName"            
        }
    }
    catch {
        Write-Error("Exception occurred trying to provision $throughput RUs for $containerResourceName. Exception: $($_.Exception).")

        $status = [HttpStatusCode]::InternalServerError
        $body = "Something went wrong trying to provision $throughput resources units for $containerResourceName"
    }
    finally {
        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $status
            Body = $body
        })
    }
}