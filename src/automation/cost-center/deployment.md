# Cost Center Tagging Serverless Automation

This project contains an automation workflow for cost center tagging, using Serverless technologies on Azure. This solution is described in more detail in Azure Architecture center in the [Event-based cloud automation](https://docs.microsoft.com/azure/architecture/reference-architectures/serverless/cloud-automation) article.

## Prerequisites

- Azure subscription
- [Azure Function Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local)

## Deploy the cost center automation artifacts

<a href="https://shell.azure.com" title="Launch Azure Cloud Shell"><img name="launch-cloud-shell" src="https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png" /></a>

Clone the repo

```bash
git clone https://github.com/mspnp/serverless-automation
```

The deployment steps shown here use bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/about) to run Bash.

### Export the automation variables representing the assets

```bash
export SUBSCRIPTION_ID=<subscription-id>
export RESOURCE_GROUP=<resource-group-name>
export LOCATION=<resource-group-location>
export STORAGE_ACCOUNT_NAME=<storageaccountname>
export APPSERVICE_NAME=<appservice-name>
export FUNCAPP_NAME=<funcapp-name>
```

### Deploy the logic app

```bash
az deployment group create -g $RESOURCE_GROUP -f .\logicApp\template.json  
```

### Deploy the Azure Function that responds to the Logic App

```bash
az group create -n $RESOURCE_GROUP -l $LOCATION \
&& az storage account create -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --sku Standard_LRS \
&& az appservice plan create --name $APPSERVICE_NAME -g $RESOURCE_GROUP --sku S1 \
&& az functionapp create -g $RESOURCE_GROUP -n $FUNCAPP_NAME -s $STORAGE_ACCOUNT_NAME --plan $APPSERVICE_NAME \
&& az functionapp identity assign -g $RESOURCE_GROUP -n $FUNCAPP_NAME
```

### Grant the Azure Function resource policy access to the resource group

```bash
az role assignment create --assignee-object-id <serviceprincipalid> \
   --role 'Contributor' \
   --resource-group $RESOURCE_GROUP
```

### Create a policy definition for the resources that can be tagged

```bash
az policy definition create --name appendTagsIfNotExists \
                            --description "Append tags if not already defined for supported resources" \
                            --display-name "Set of billing policy rules" \
                            --mode Indexed \
                            --subscription $SUBSCRIPTION_ID \
                            --rules policies/custompolicy.rules.json \
                            --params policies/custompolicy.rules.parameters.json

```

### Enforce policy rules at the resource group level

```bash
az policy assignment create --name billingPolicy \
                            --display-name "Resource billing policy" \
                            --resource-group $RESOURCE_GROUP \
                            --policy "<policy-id-obtained-from-the-output-of-previous-command>"
```

### Publish the function app

```bash
cd ./src/automation/cost-center/cost-center-tagging
func azure functionapp publish $FUNCAPP_NAME
```
