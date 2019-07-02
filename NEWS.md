# AzureContainers 1.1.0

* Make `docker_registry` and `kubernetes_cluster` into constructor functions rather than R6 classes, for consistency with other AzureR packages. The corresponding class objects are now `DockerRegistry` and `KubernetesCluster`.
* Enable AAD authentication for ACR. By default, instantiating a new docker registry object will authenticate using the AAD credentials of the currently signed-in user. Alternative authentication details can be supplied to `docker_registry`, which will be passed to `AzureAuth::get_azure_token`. See the help for `docker_registry` for more information.
* Enable authenticating with service principals to ACR from ACI and AKS.
* By default, create new container instances with a managed service identity.

# AzureContainers 1.0.3

* Add `aks$update_service_password()` method to reset/update the service principal credentials.
* Send the docker password via `stdin`, rather than on the commandline.

# AzureContainers 1.0.2

* Ensure dir for Kubernetes config file exists before writing the file.
* Add `wait` argument to `create_aci` and `create_aks` methods; rely on AzureRMR 2.0 for implementation.
* By default, create a new service principal when creating a new AKS resource; this relies on the AzureGraph package.
* Fix bug in `aci$start()` method.
* By default, save the config file for an AKS cluster in the AzureR directory to allow reuse without going through Resource Manager.

# AzureContainers 1.0.1

* Change `aks$get_cluster()` method to use a non-deprecated API call.
* Allow resource group and subscription accessor methods to work even if AzureContainers is not on the search path.
* Allow for different AAD token implementations, either from httr or AzureAuth.

# AzureContainers 1.0.0

* Submitted to CRAN

# AzureContainers 0.9.0

* Moved to cloudyr organisation
