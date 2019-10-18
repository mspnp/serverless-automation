# Drone Delivery Serverless Automation (Powershell)

## Deploy the Powershell Core Azure Function that respond to 429s

```bash
export COSMOSDB_ACCOUNT_NAME=$DRONESCHEDULER_COSMOSDB_NAME \
&& az group deployment create \
   -g $RESOURCE_GROUP_AUTO \
   -n azuredeploy-pwsh \
   --template-file ./azuredeploy-pwsh.json \
   --parameters cosmosDbResourceGroup=$RESOURCE_GROUP \
                cosmosDbAccountName=$COSMOSDB_ACCOUNT_NAME \
                cosmosDbDatabaseName=$DATABASE_NAME \
                cosmosDbContainerName=$COLLECTION_NAME \
                cosmosDbContainerMaxRUs=2500 \
&& export FUNCAPP_NAME=$(az group deployment show -g $RESOURCE_GROUP_AUTO -n azuredeploy-pwsh --query properties.outputs.throttlingRespondFunctionAppName.value -o tsv) \
&& export FUNCAPP_NAME_SYSTEM_MANAGED_PRINCIPAL_ID=$(az group deployment show -g $RESOURCE_GROUP_AUTO -n azuredeploy-pwsh --query properties.outputs.throttlingRespondFunctionAppSystemAssignedPrincipalId.value -o tsv) \
&& az group deployment create \
   -g $RESOURCE_GROUP \
   -n azuredeploy-roleassignment-pwsh \
   --template-file ./azuredeploy-roleassignment.json \
   --parameters cosmosDbAccountName=$COSMOSDB_ACCOUNT_NAME \
                throttlingRespondFunctionAppName=$FUNCAPP_NAME \
                throttlingRespondFunctionAppSystemAssignedPrincipalId=$FUNCAPP_NAME_SYSTEM_MANAGED_PRINCIPAL_ID \
&& cd ./src/automation/throttling-responder/throttling-respond/ \
&& func pack --build-native-deps \
&& az functionapp deployment source config-zip \
      -g $RESOURCE_GROUP_AUTO \
      -n $FUNCAPP_NAME \
      --src ./throttling-respond.zip \
&& cd -
```

### Validate

```bash
export FUNC_NAME=cosmosdb-provision-rus \
&& export FUNCAPP_CODE=$(az rest --method post --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_AUTO}/providers/Microsoft.Web/sites/${FUNCAPP_NAME}/functions/${FUNC_NAME}/listKeys?api-version=2018-02-01" --query default -o tsv) \
&& curl -i -XPOST "https://${FUNCAPP_NAME}.azurewebsites.net/api/${FUNC_NAME}?code=${FUNCAPP_CODE}" -H "Content-Type:application/json" -d '{"schemaId": "test"}'
```

> Note: it will respond with a bad request status as this is expecting a body with the [Common Alert Schema defnitiion](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-common-schema-definitions)

### Create Azure Monitor alert and action group

```bash
export ALERT_NAME="throttling-alert" && \
export ACTIONGROUP_NAME="throttling-actiongroup" && \
export ACTION_NAME="throttling-notifyazfunc"

az group deployment create \
   -g $RESOURCE_GROUP \
   -n azuredeploy-monitoring \
   --template-file ./azuredeploy-monitoring.json \
   --parameters cosmosDbAccountName=$COSMOSDB_ACCOUNT_NAME \
                throttlingRespondMetricAlertName=$ALERT_NAME \
                throttlingRespondFunctionAppName=$FUNCAPP_NAME \
                throttlingRespondFunctionAppResourceGroup=$RESOURCE_GROUP_AUTO \
                throttlingRespondActionGroupName=$ACTIONGROUP_NAME \
                throttlingRespondActionFunctionReceiverName=$ACTION_NAME \
                throttlingRespondFunctionName=$FUNC_NAME \
                throttlingRespondFunctionKey=$FUNCAPP_CODE
```

#### Navigate back to the README.md to validate this setup

Click [here](./deployment.md#Alerting_and_action_group_triggering_function_validation) to navigate back to the main validation section.
