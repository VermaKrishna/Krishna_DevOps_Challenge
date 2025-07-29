#Setup steps:

## Prerequisites

Before running the Terraform scripts, ensure you have the following prerequisites configured:
1. Create a service Principal and give contributor access on Subscription(this access can me moderated)
2. Create a storage account( I wanted to create using Github actions but could not due to lack of time)

Once you have created then add service Principal and storage details as repo secrets. Steps below.

### Azure Service Principal for Authentication

You need an Azure Service Principal with sufficient permissions (Contributor or higher). The following environment variables must be set for Terraform to authenticate with Azure:

- `ARM_CLIENT_ID` - Azure Service Principal Client ID
- `ARM_CLIENT_SECRET` - Azure Service Principal Client Secret
- `ARM_SUBSCRIPTION_ID` - Azure Subscription ID
- `ARM_TENANT_ID` - Azure Active Directory Tenant ID

### Terraform Remote State Backend Configuration

The Terraform state is stored remotely in an Azure Storage Account. The following backend configuration values must be provided via environment variables or GitHub secrets:

- `TF_STATE_RG` - Resource Group name where the Terraform state storage account exists
- `TF_STATE_STORAGE` - Storage Account name used for Terraform state
- `TF_STATE_CONTAINER` - Blob container name inside the Storage Account
- `TF_STATE_KEY` - The key (filename) for the Terraform state file (e.g. `static-site.tfstate`)

These will be passed to Terraform using `-backend-config` parameters:

```bash
terraform init \
  -backend-config="resource_group_name=${TF_STATE_RG}" \
  -backend-config="storage_account_name=${TF_STATE_STORAGE}" \
  -backend-config="container_name=${TF_STATE_CONTAINER}" \
  -backend-config="key=${TF_STATE_KEY}"
