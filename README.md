# Event-based Cloud Automation

Automating workflows and repetitive tasks on the cloud using [serverless technologies](https://azure.microsoft.com/solutions/serverless/), can dramatically improve productivity of an organization's DevOps team. A serverless model is best suited for automation scenarios that fit an [event driven approach](https://docs.microsoft.com/azure/architecture/guide/architecture-styles/event-driven).

This repository contains an implementation of the "Cost center tagging" example as presented on the [Event-based cloud automation](https://docs.microsoft.com/azure/architecture/reference-architectures/serverless/cloud-automation) article in the Azure Architecture Center.

## [Cost center tagging automation workflow](./src/automation/cost-center/deployment.md)

This project contains a workflow for cost center tagging, as a serverless automation scenario. It applies a policy on a resource group to tag all new resources with cost center information. It then watches for resources in this group having that tag, and validates the cost center using Azure AD. If the cost center has changed, it applies the new cost center tags to the resource. Irrespective of whether the cost center has changed or not, it sends an email to the resource creator/owner with context of the resource created.
