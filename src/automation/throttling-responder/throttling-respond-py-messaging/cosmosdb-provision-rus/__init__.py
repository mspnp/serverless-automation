# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

import json
import logging
import os

import azure.functions as func

from .cosmosdb.client_factory import get_client_using_msi_profile

client = get_client_using_msi_profile()

resource_group_name=os.environ["CosmosDbResourceGroup"]
account_name=os.environ["CosmosDbAccountName"]
database_name=os.environ["CosmosDbDatabaseName"]
container_name=os.environ["CosmosDbContainterName"]
container_rus={'throughput' : os.environ["CosmosDbRUs"]}
def main(msg: func.ServiceBusMessage):
    
    logging.info("Python Cosmos DB messaging automation function receiving message {0}"
    .format(
        msg.message_id
    ))

    try:
        msg_body = msg.get_body().decode('utf-8')
        msg_json = json.loads(msg_body)
        
        resource_group_name_res_id = msg_json['resource_group_name']
        account_name_res_id = msg_json['account_name']
        
        if resource_group_name != resource_group_name_res_id:
            raise ValueError('Invalid Alert Resource Group. Expected alert for resource group {0} and received {1}. Review the Azure Metric Alert and action group configuration.'.format(resource_group_name, resource_group_name_res_id))
        if account_name != account_name_res_id:
            raise ValueError('Invalid Alert Cosmos Db Account. Expected alert for cosmos db account {0} and received {1}. Review the Azure Metric Alert and action group configuration.'.format(account_name, account_name_res_id))
    except ValueError as err:
        logging.error(err.args)
        raise
    else:
        alert_rule_name=msg_json['alert_rule_name']
        severity=msg_json['severity']
    
    logging.info('Python Cosmos DB messaging automation function processing alert {0} with severity {1}'
    .format(
        alert_rule_name,
        severity
    ))

    try:
        client.database_accounts.update_sql_container_throughput(
            resource_group_name, 
            account_name, 
            database_name, 
            container_name, 
            resource=container_rus)

        logging.info('Successfully provisioned {0} resources units for {1}/sql/{2}/{3}'
            .format(
                container_rus["throughput"],
                account_name,
                database_name,
                container_name))
    except Exception as e:
        logging.error('\ncosmosdb-provision-rus has caught an error. {0}'.format(e))
        # since Azure Functions Service trigger are using PeekLock connection mode we expect this raise to send this message to the DLQ
        raise
    finally:
        logging.info("\ncosmosdb-provision-rus done")