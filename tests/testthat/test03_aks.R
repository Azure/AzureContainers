context("AKS interface")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

acrname <- Sys.getenv("AZ_TEST_ACR")
if(acrname == "")
    skip("AKS tests skipped: resource names not set")


test_that("AKS works",
{
    rgname <- Sys.getenv("AZ_TEST_RG")
    rg <- AzureRMR::az_rm$
        new(tenant=tenant, app=app, password=password)$
        get_subscription(subscription)$
        get_resource_group(rgname)

    acr <- rg$get_acr(acrname)
    expect_true(is_acr(acr))
    reg <- acr$get_docker_registry()
    expect_true(is_docker_registry(reg))

    expect_is(rg$list_kubernetes_versions(), "character")

    aksname <- paste0(sample(letters, 10, TRUE), collapse="")
    expect_true(is_aks(rg$create_aks(aksname, agent_pools=aks_pools("pool1", 3))))

    expect_true(is_aks(rg$list_aks()[[1]]))
    aks <- rg$get_aks(aksname)
    expect_true(is_aks(aks))

    aks$update_service_password()

    clus <- aks$get_cluster()
    expect_true(is_kubernetes_cluster(clus))

    hello_yaml <- gsub("acrname", acrname, readLines("../resources/hello.yaml"))
    clus$create_registry_secret(reg, email="me@example.com")
    clus$create(hello_yaml)
})
