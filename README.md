# Drone Delivery Serverless Automation

This reference implementation contains two serverless automation scenarios as described below.

## [Throttling response serverless workflow](https://github.com/mspnp/serverless-automation/throttling-responder/deployment.md)

This project contains a workflow for throttling response as a serverless automation scenario. It will provision more resource units for Cosmos DB container when throttling is detected, via Azure Monitor alerts and Azure Action Groups. This automation is available both as Python and Powershell Core (Preview) based Azure Functions. Python implementation builds on top by adding a messaging workflow that handles an HTTP request timeout.

## [Cost center tagging automation workflow](https://github.com/mspnp/serverless-automation/cost-center/deployment.md)

This project contains a workflow for cost center tagging, as a serverless automation scenario. It applies a policy on a resource group to tag all new resources with cost center information. It then watches for resources in this group having that tag, and validates the cost center using Azure AD. If the cost center has changed, it applies the new cost center tags to the resource. Irrespective of whether the cost center has changed or not, it sends an email to the resource creator/owner with context of the resource created.
