provider "azurerm" {
  features {}
}

resource "random_string" "random" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

resource "azurerm_resource_group" "iac-proj" {
  name     = "example-resources"
  location = "eastus"
}

resource "azurerm_storage_account" "iac-proj-storage" {
  name                     = "funcstorageacc${random_string.random.result}"
  resource_group_name      = azurerm_resource_group.iac-proj.name
  location                 = azurerm_resource_group.iac-proj.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_storage_container" "storage_container_function" {
  name                 = "function-releases"
  storage_account_name = azurerm_storage_account.iac-proj-storage.name
}

resource "azurerm_role_assignment" "role_assignment_storage" {
  scope                = azurerm_storage_account.iac-proj-storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.iac-proj-function.identity.0.principal_id
  #principal_id                     = azurerm_function_app.function-app.identity.0.principal_id

}
resource "azurerm_storage_blob" "storage_blob_function" {
  name                   = "functions-${substr(data.archive_file.function.output_md5, 0, 6)}.zip"
  storage_account_name   = azurerm_storage_account.iac-proj-storage.name
  storage_container_name = azurerm_storage_container.storage_container_function.name
  type                   = "Block"
  content_md5            = data.archive_file.function.output_md5
  source                 = "${path.module}/functions.zip"
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "../src"
  output_path = "${path.module}/functions.zip"

}

resource "azurerm_service_plan" "iac-proj-service" {
  name                = "iacservice"
  resource_group_name = azurerm_resource_group.iac-proj.name
  location            = azurerm_resource_group.iac-proj.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_windows_function_app" "iac-proj-function" {
  name                = "iacfunction"
  resource_group_name = azurerm_resource_group.iac-proj.name
  location            = azurerm_resource_group.iac-proj.location

  storage_account_name       = azurerm_storage_account.iac-proj-storage.name
  storage_account_access_key = azurerm_storage_account.iac-proj-storage.primary_access_key
  service_plan_id            = azurerm_service_plan.iac-proj-service.id
  identity {
    type = "SystemAssigned"
  }
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME   = "powershell"
    "WEBSITE_RUN_FROM_PACKAGE" = azurerm_storage_blob.storage_blob_function.url
    AzureWebJobsStorage        = azurerm_storage_account.iac-proj-storage.primary_blob_connection_string
  }

  site_config {}
}
