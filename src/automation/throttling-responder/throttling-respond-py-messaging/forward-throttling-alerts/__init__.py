# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

import json
import logging

import azure.functions as func

def main(req: func.HttpRequest, msg: func.Out[str]) -> func.HttpResponse:
    
    try:
        req_body = req.get_json()
        schema_id=req_body['schemaId']
        if schema_id != 'azureMonitorCommonAlertSchema':
            return func.HttpResponse(
                'Invalid schema id {0}, it must be azureMonitorCommonAlertSchema.'.format(schema_id),
                status_code=400
            )
        monitor_condition=req_body['data']['essentials']['monitorCondition']
        if monitor_condition != 'Fired':
            skip_msg='Skipping execution because received an alert notification with monitor condition {0}, while the only valid condition to be process is Fired'.format(monitor_condition)
            logging.info(skip_msg)
            return func.HttpResponse(
                skip_msg,
                status_code=200
            )
    except ValueError as err:
        logging.error(err.args)
        raise
    else:
        essentials=req_body['data']['essentials']
        resource_id=essentials['alertTargetIDs'][0].split('/')
        resource_id.pop(0)
        resource_id_dict=dict(zip(resource_id, resource_id[1:] + [0]))
        msg_data={}
        msg_data["alert_rule_name"] = essentials['alertRule']
        msg_data["severity"] = essentials['severity']
        msg_data["resource_group_name"] = resource_id_dict['resourcegroups']
        msg_data["account_name"] = resource_id_dict['databaseaccounts']
    
    logging.info('Python Cosmos DB messaging automation function forwarding alert {0} with severity {1}'
    .format(
        msg_data["alert_rule_name"],
        msg_data["severity"]
    ))
    
    msg.set(json.dumps(msg_data))

    return 'OK'