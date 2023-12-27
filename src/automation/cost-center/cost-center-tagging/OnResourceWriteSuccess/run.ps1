# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Information "PowerShell HTTP trigger function processed a request."
$dataReceived = $Request.Body

Write-Debug "EventGrid event raw details"
$dataReceived | ConvertTo-Json | Write-Information

Write-Debug "Trigger metadata raw details"
$TriggerMetadata | ConvertTo-Json | Write-Information

# Find the tags associated with the new resource to be sent
$resourceId = $dataReceived['resourceUri']
Write-Information "Finding existing tags associated with Resource Id: $resourceId"

$tags = (Get-AzResource -ResourceId $resourceId).tags
Write-Information "Tags"
$tags | Out-String | Write-Information

# Get the cost center for the user service principal (such as Id or email id)
Write-Information "Querying Entra ID to validate the cost center..."

##########################################################################################################################
# Below is an example of a graph query Uri and a REST call to your organization's Entra ID. Note the use of claims/upn that contains
# the email id of the resource creator. Query may need to be adjusted, based on the data being returned by Entra ID
# To learn, how to use Microsoft identity platform, visit - https://learn.microsoft.com/graph/auth-register-app-v2
# To learn, how to use Graph API, visit - https://learn.microsoft.com/graph/graph-explorer/graph-explorer-overview
##########################################################################################################################
## $graphQueryUri = "https://graph.microsoft.com/v1.0/users/" + $dataReceived['claims']['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn'] + "?$select=costcenter"
## $response = Invoke-WebRequest -Uri $graphQueryUri -ContentType "application/json" -Method GET -Headers @{Authorization = "Bearer $token"} -ErrorAction Stop

# Parse response to obtain cost center 
$costCenterEntraId = 'enter-cost-center-obtained-from-entra-id-query' # Cost center value obtained from Microsoft Graph query into Entra ID

$updateResource = $false
if ($tags -and $tags.ContainsKey('CostCenter')) {
    Write-Information "Policy enforced cost center: $($tags.CostCenter)" 
    if ($tags.CostCenter -ne $costCenterEntraId) {
        Write-Information "Policy enforced cost center is invalid. Assigning cost center $costCenterEntraId to the resource $resourceId..."
        $updateResource = $true
    }
}
else {
    Write-Information "No cost center assigned. Assigning cost center $costCenterEntraId to the resource $resourceId..."
    $updateResource = $true
}

try {
    $status = [HttpStatusCode]::OK
    if ($updateResource) {
        if ($null -eq $tags) { $tags = @{ } }
        $tags.CostCenter = $costCenterEntraId
        Set-AzResource -Tag $tags -ResourceId $resourceId -Force -ErrorAction Stop
    }

    $body = $tags
}
catch {
    Write-Error("Exception occurred trying to tag $resourceId - Exception: $($_.Exception).")
    $status = [HttpStatusCode]::InternalServerError
    $body = "Exception occured trying to tag $resourceId. Please check logs for details."
}
finally {

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $status
            Body       = $body
        })
}
