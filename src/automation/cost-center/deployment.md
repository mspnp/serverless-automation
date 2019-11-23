# Cost Center Tagging Serverless Automation

This project contains an automation workflow for cost center tagging, using Serverless technologies on Azure.

## Prerequisites

- Azure subscription
- [Azure Function Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local#v2)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

## Deploy the cost center automation artifacts

<a href="https://shell.azure.com" title="Launch Azure Cloud Shell"><img name="launch-cloud-shell" src="https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png" /></a>

Clone the repo locally

```bash
git clone https://github.com/mspnp/serverless-automation
```

The deployment steps shown here use bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/about) to run Bash. [Login to your Azure subscription](https://docs.microsoft.com/cli/azure/authenticate-azure-cli?view=azure-cli-latest) before starting.

### Export the automation variables representing the assets

```bash
export SUBSCRIPTION_ID=<subscription-id>
export RESOURCE_GROUP=<resource-group-name>
export LOCATION=<resource-group-location>
export STORAGE_ACCOUNT_NAME=<storageaccountname>
export APPSERVICE_NAME=<appservice-name>
export FUNCAPP_NAME=<funcapp-name>
```

### Deploy the azure function that responds to the logic app

```bash
az group create -n $RESOURCE_GROUP -l $LOCATION \
&& az storage account create -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --sku Standard_LRS \
&& az appservice plan create --name $APPSERVICE_NAME -g $RESOURCE_GROUP --sku S1 \
&& az functionapp create -g $RESOURCE_GROUP -n $FUNCAPP_NAME -s $STORAGE_ACCOUNT_NAME --plan $APPSERVICE_NAME \
&& : turn on system assigned managed identity \
&& az functionapp identity assign -g $RESOURCE_GROUP -n $FUNCAPP_NAME
```

### Grant azure function resource policy access to the resource group

Replace the <serviceprincipalid> with the service principal ID obtained from the *az functionapp identity assign* command:

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

Note that this resource group could be different from the automation resource group.

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

### Deploy the logic app

On command line, navigate to /src/automation/cost-center/cost-center-tagging/ and run this command:

```bash
az group deployment create -g $RESOURCE_GROUP --template-file ./logicApp/template.json --parameters ReactorFunctionName=$FUNCAPP_NAME
```

### Deploy a resource to tag

Run any resource creation command on Azure CLI, such as:

```bash
az network vnet create -g $RESOURCE_GROUP -n <vnetname>
```
Note that this resource group is the same as the one with the policy rules set above.

### Troubleshooting

You should receive email notifications for every resource you create in the monitored resource group. 

If you don't receive it, try following troubleshooting steps:

1) Sign in to Logic App connectors: Login to [Azure Portal](portal.azure.com), navigate to the Logic App created in the automation resource, click Edit, and in the Logic App Designer, click on the input and output connectors. Both of them might need to be additionally signed in and authenticated, depending on your tenant's AAD settings. Once done, restart the logic app, and create another resource to verify.
2) Make sure the right subscription is used in the Logic App input connector (azureeventgrid): In the Logic App Designer, open the input connector ("When a resource event occurs", click on the *Subscription*, and if Fx(Subscription) shows up, remove it, and select the correct subscription from the drop down. This bug will be fixed in the next iteration.
