context("Resource group creation")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

Sys.setenv(AZ_TEST_RG=paste(sample(letters, 20, replace=TRUE), collapse=""))
Sys.setenv(AZ_TEST_ACR=paste(sample(letters, 10, replace=TRUE), collapse=""))

test_that("Resource group creation succeeds",
{
    sub <- AzureRMR::az_rm$
        new(tenant=tenant, app=app, password=password)$
        get_subscription(subscription)

    rgname <- Sys.getenv("AZ_TEST_RG")

    expect_false(sub$resource_group_exists(rgname))
    rg <- sub$create_resource_group(rgname, location="australiaeast")
    expect_true(sub$resource_group_exists(rgname))
})

