context("AKS-ACR interop with managed identity")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

rgname <- make_name(10)
rg <- AzureRMR::az_rm$
    new(tenant=tenant, app=app, password=password)$
    get_subscription(subscription)$
    create_resource_group(rgname, location="australiaeast")

aksname <- make_name(10)
aks <- rg$create_aks(aksname, agent_pools=aks_pools("pool1", 2), managed_identity=TRUE)

test_that("AKS/ACR works with managed identity",
{
    acrname <- make_name(10)
    acr <- rg$create_acr(acrname, admin_user_enabled=TRUE)
    reg <- acr$get_docker_registry(as_admin=TRUE)
    expect_true(is_docker_registry(reg))

    cmdline <- "build -f ../resources/hello_dockerfile -t hello-world ."
    call_docker(cmdline)

    reg$push("hello-world")

    cmdline <- paste0("image rm ", acrname, ".azurecr.io/hello-world")
    call_docker(cmdline)

    expect_true(is_aks(aks))

    clus <- aks$get_cluster()
    expect_true(is_kubernetes_cluster(clus))

    hello_yaml <- gsub("acrname", acrname, readLines("../resources/hello.yaml"))
    clus$create_registry_secret(reg, email="me@example.com")
    clus$create(hello_yaml)
})


test_that("AKS/ACR works with managed identity/RBAC",
{
    acrname <- make_name(10)
    acr <- rg$create_acr(acrname, admin_user_enabled=FALSE)
    reg <- acr$get_docker_registry(as_admin=FALSE)
    expect_true(is_docker_registry(reg))

    cmdline <- "build -f ../resources/hello_dockerfile -t hello-world ."
    call_docker(cmdline)

    reg$push("hello-world")

    cmdline <- paste0("image rm ", acrname, ".azurecr.io/hello-world")
    call_docker(cmdline)

    acr$add_role_assignment(aks, "Acrpull")

    clus <- aks$get_cluster()
    expect_true(is_kubernetes_cluster(clus))

    hello_yaml <- gsub("acrname", acrname, readLines("../resources/hello.yaml"))
    hello_yaml <- gsub("hellodep", "hellodep-rb", hello_yaml)
    clus$create(hello_yaml)
})


teardown({
    suppressMessages(rg$delete(confirm=FALSE))
})
