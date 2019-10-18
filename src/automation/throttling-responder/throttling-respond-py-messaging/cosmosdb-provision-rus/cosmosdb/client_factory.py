# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for
# license information.
# ------------------------------------------------------------

from msrestazure.azure_active_directory import MSIAuthentication
from azure.mgmt.resource import SubscriptionClient
import azure.mgmt.cosmosdb as cosmosdbmgmt

__credentials__ = MSIAuthentication()
__subscription_client__ = SubscriptionClient(__credentials__)
__subscription__ = next(__subscription_client__.subscriptions.list())
__subscription_id__ = __subscription__.subscription_id

def get_client_using_msi_profile():
    """Return a SDK client initialized with MSI credentials using default subscription
    """

    return cosmosdbmgmt.CosmosDB(__credentials__, __subscription_id__)