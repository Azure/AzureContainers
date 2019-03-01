# AzureContainers 1.0.1.9000

* Ensure dir for Kubernetes config file exists before writing the file
* Add `wait` argument to `create_aci` and `create_aks` methods; rely on AzureRMR 2.0 for implementation

# AzureContainers 1.0.1

* Change `aks$get_cluster()` method to use a non-deprecated API call.
* Allow resource group and subscription accessor methods to work even if AzureContainers is not on the search path.
* Allow for different AAD token implementations, either from httr or AzureAuth.

# AzureContainers 1.0.0

* Submitted to CRAN

# AzureContainers 0.9.0

* Moved to cloudyr organisation
