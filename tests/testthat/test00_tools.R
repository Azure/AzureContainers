context("Tools interface")

if(.AzureContainers$docker == "" ||
   .AzureContainers$dockercompose == "" ||
   .AzureContainers$kubectl == "" ||
   .AzureContainers$helm == "")
    skip("Tests skipped: external tools not found")

echo <- getOption("azure_containers_tool_echo")
options(azure_containers_tool_echo=FALSE)

test_that("Docker works",
{
    cmd <- "--help"
    obj <- call_docker(cmd)
    expect_is(obj, "list")
    expect_identical(obj$cmdline, "docker --help")
})

test_that("Docker compose works",
{
    cmd <- "--help"
    obj <- call_docker_compose(cmd)
    expect_is(obj, "list")
    expect_identical(obj$cmdline, "docker-compose --help")
})

test_that("Kubectl works",
{
    cmd <- "--help"
    obj <- call_kubectl(cmd)
    expect_is(obj, "list")
    expect_identical(trimws(obj$cmdline), "kubectl --help")
})

test_that("Helm works",
{
    cmd <- "--help"
    obj <- call_helm(cmd)
    expect_is(obj, "list")
    expect_identical(trimws(obj$cmdline), "helm --help")
})

teardown({
    options(azure_containers_tool_echo=echo)
})
