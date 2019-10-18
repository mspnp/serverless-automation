# Throttling Response Serverless Automation

This project contains a reference implementation for a serverless automation scenario. It will provision more RU for Cosmos DB container when throttling is detected.

<a href="https://shell.azure.com" title="Launch Azure Cloud Shell"><img name="launch-cloud-shell" src="https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png" /></a>

The deployment steps shown here use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/about) to run Bash.

## Prerequisites
- Azure subscription
- [Docker](https://docs.docker.com/)
- [Python 3.6](https://www.python.org/downloads/), with the python executable available in your PATH.
- [Azure Function Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local#v2)
- [Microservices perf tuning reference implementation](https://github.com/mspnp/microservices-perftuning)

## Clone this repo locally.

```bash
git clone https://github.com/mspnp/serverless-automation && \
cd ./src/automation/throttling-responder
```

## Deploy the throttling automation respond scenario

### Validate env vars from prerequisites

```bash 
# execute the following to validate you have all the prerequisites before continuing
[ -z "$DRONESCHEDULER_COSMOSDB_NAME" ] && echo "WARNING: verify you created the cosmosdb account in microservices perf tuning ri" || \
[ -z "$DATABASE_NAME" ] && echo "WARNING: verify you created the cosmosdb database in microservices perf tuning ri" || \
[ -z "$COLLECTION_NAME" ] && echo "WARNING: verify you created the cosmosdb container in microservices perf tuning ri" || echo "everything seems to be ok, please continue..."
```
 
### Create resource group

```bash
export LOCATION=<location>
export RESOURCE_GROUP_AUTO=<resource-group>

az group create -n $RESOURCE_GROUP_AUTO -l $LOCATION
```

### Deploy the messaging Python Azure Function that respond to 429s

> Note: this additional workflow demonstrates how to avoid possible HTTP timeouts.

```bash
export COSMOSDB_ACCOUNT_NAME=$DRONESCHEDULER_COSMOSDB_NAME \
&& az group deployment create \
   -g $RESOURCE_GROUP_AUTO \
   -n azuredeploy \
    --template-uri "https://raw.githubusercontent.com/mspnp/serverless-automation/master/throttling-responder/azuredeploy.json" \
   --parameters cosmosDbResourceGroup=$RESOURCE_GROUP \
                cosmosDbAccountName=$COSMOSDB_ACCOUNT_NAME \
                cosmosDbDatabaseName=$DATABASE_NAME \
                cosmosDbContainerName=$COLLECTION_NAME \
                cosmosDbContainerMaxRUs=2500 \
&& export FUNCAPP_NAME=$(az group deployment show -g $RESOURCE_GROUP_AUTO -n azuredeploy --query properties.outputs.throttlingRespondFunctionAppName.value -o tsv) \
&& cd ./src/automation/throttling-responder/throttling-respond-py-messaging/ \
&& func pack --build-native-deps \
&& az functionapp deployment source config-zip \
      -g $RESOURCE_GROUP_AUTO \
      -n $FUNCAPP_NAME \
      --src ./throttling-respond-py-messaging.zip \
&& cd -
```

> Note: while deploying this Azure Function, the first time you may face a Bad Request. If that is the case, please try it again.

### Validate

```bash
export FUNC_NAME=$(az group deployment show -g $RESOURCE_GROUP_AUTO -n azuredeploy --query properties.outputs.throttlingRespondFunctionName.value -o tsv) \ 
&& export FUNCAPP_CODE=$(az rest --method post --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_AUTO}/providers/Microsoft.Web/sites/${FUNCAPP_NAME}/functions/${FUNC_NAME}/listKeys?api-version=2018-02-01" --query default -o tsv) \
&& curl -i -XPOST "https://${FUNCAPP_NAME}.azurewebsites.net/api/${FUNC_NAME}?code=${FUNCAPP_CODE}" -H "Content-Type:application/json" -d '{"schemaId": "test"}'
```

> Note: it will respond with a bad request status as this is expecting a body with the [Common Alert Schema definition](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-common-schema-definitions)

#### Alert and trigger function validation using Action Groups

1. Reduce the amount of resource units to the minimum.

```bash
az cosmosdb collection update \
   -g $RESOURCE_GROUP \
   --name $COSMOSDB_ACCOUNT_NAME \
   --db-name $DATABASE_NAME \
   --collection-name $COLLECTION_NAME \
   --throughput 900
```

2. Execute the microservices perf tuning [reference implementation load test](https://github.com/mspnp/microservices-perftuning#execute-the-load-test) and follow up the 429s from the `Fabrikam Monitoring dashboard`

3. It's recommended to have also open the Azure Monitor Alert blade, that can be accessed from the `Fabrikam Monitoring dashboard`
   
   > note: this alert will be eventually resolved.

4. After it gets resolved, navigate to the Azure Cosmos DB overview blade and notice that the container thoughput is now higher than the original throughput value.

### Optionally deploy the Powershell Core Azure Function that respond to 429s

Navigate to the Powershell Core deployment steps [here](./deployment-pwsh.md).
