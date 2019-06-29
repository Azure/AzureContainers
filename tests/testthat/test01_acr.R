context("ACR interface")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

acrname <- Sys.getenv("AZ_TEST_ACR")
if(acrname == "")
    skip("ACR tests skipped: resource name not set")

rgname <- Sys.getenv("AZ_TEST_RG")
rg <- AzureRMR::az_rm$
    new(tenant=tenant, app=app, password=password)$
    get_subscription(subscription)$
    get_resource_group(rgname)

test_that("ACR works",
{
    expect_true(is_acr(rg$create_acr(acrname)))
    acr <- rg$get_acr(acrname)
    expect_true(is_acr(acr))

    acr2 <- rg$list_acrs()[[1]]
    expect_true(is_acr(acr2))

    reg <- acr$get_docker_registry()
    expect_true(is_docker_registry(reg))

    cmdline <- "build -f ../resources/hello_dockerfile -t hello-world ."
    output <- call_docker(cmdline)
    expect_equal(attr(output, "cmdline"), paste("docker", cmdline))

    reg$push("hello-world")

    cmdline <- paste0("image rm ", acrname, ".azurecr.io/hello-world")
    call_docker(cmdline)

    expect_equal(reg$list_repositories(), "hello-world")
})

test_that("ACR works with app login",
{
    acr <- rg$get_acr(acrname)
    expect_true(is_acr(acr))

    acr$add_role_assignment(
        principal=AzureGraph::get_graph_login(tenant)$get_app(app),
        role="owner"
    )

    reg <- acr$get_docker_registry(username=app, password=password)
    expect_true(is_docker_registry(reg))
    expect_identical(reg$username, app)

    cmdline <- "build -f ../resources/hello_dockerfile -t hello-world-sp ."
    output <- call_docker(cmdline)
    expect_equal(attr(output, "cmdline"), paste("docker", cmdline))

    reg$push("hello-world-sp")

    cmdline <- paste0("image rm ", acrname, ".azurecr.io/hello-world-sp")
    call_docker(cmdline)

    expect_equal(reg$list_repositories(), c("hello-world", "hello-world-sp"))
})
