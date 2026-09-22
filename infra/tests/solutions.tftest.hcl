# Exercises the solutions module directly so the fixture stays independent of
# the committed configuration, apart from the real package path it resolves.
mock_provider "powerplatform" {}

variables {
  deployments = {
    "SampleSolution/test" = {
      environment_id        = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
      unique_name           = "SampleSolution"
      version               = "1.0.0.2"
      file                  = "../solutions/TerrraformExampleSolution_managed.zip"
      environment_variables = { bal_MagicNumber = "42" }
    }
  }
}

run "imports_the_package" {
  command = plan
  module { source = "./modules/power-platform/solutions" }

  assert {
    condition = (
      powerplatform_managed_solution.deployments["SampleSolution/test"].unique_name == "SampleSolution" &&
      powerplatform_managed_solution.deployments["SampleSolution/test"].version == "1.0.0.2" &&
      powerplatform_managed_solution.deployments["SampleSolution/test"].source.path == "../solutions/TerrraformExampleSolution_managed.zip" &&
      powerplatform_managed_solution.deployments["SampleSolution/test"].environment_id == "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    )
    error_message = "Each deployment must import its own package into its own environment."
  }

  # Sending an empty map instead of null risks provider round-trip errors.
  assert {
    condition = (
      powerplatform_managed_solution.deployments["SampleSolution/test"].connection_references == null &&
      !powerplatform_managed_solution.deployments["SampleSolution/test"].publish_all_customizations &&
      !powerplatform_managed_solution.deployments["SampleSolution/test"].skip_product_update_dependencies
    )
    error_message = "Unset connection references must stay null, and import behavior must default to off."
  }

  assert {
    condition = (
      powerplatform_environment_variable_value.values["SampleSolution/test/bal_MagicNumber"].schema_name == "bal_MagicNumber" &&
      powerplatform_environment_variable_value.values["SampleSolution/test/bal_MagicNumber"].value == "42" &&
      powerplatform_environment_variable_value.values["SampleSolution/test/bal_MagicNumber"].environment_id == "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    )
    error_message = "Environment variable values must follow their solution into the same environment."
  }
}

run "no_environment_variables" {
  command = plan
  module { source = "./modules/power-platform/solutions" }
  variables {
    deployments = {
      "SampleSolution/test" = merge(var.deployments["SampleSolution/test"], { environment_variables = {} })
    }
  }
  assert {
    condition     = length(output.environment_variable_values) == 0
    error_message = "A solution without configured values must not manage any environment variable."
  }
}

run "reject_schema_name_without_prefix" {
  command = plan
  module { source = "./modules/power-platform/solutions" }
  variables {
    deployments = {
      "SampleSolution/test" = merge(var.deployments["SampleSolution/test"], {
        environment_variables = { MagicNumber = "42" }
      })
    }
  }
  expect_failures = [var.deployments]
}

run "no_solutions" {
  command = plan
  module { source = "./modules/power-platform/solutions" }
  variables {
    deployments = {}
  }
  assert {
    condition     = length(output.solution_ids) == 0
    error_message = "An empty configuration must not plan any solution import."
  }
}

run "reject_missing_package" {
  command = plan
  module { source = "./modules/power-platform/solutions" }
  variables {
    deployments = {
      "SampleSolution/test" = merge(var.deployments["SampleSolution/test"], {
        file = "../solutions/DoesNotExist_managed.zip"
      })
    }
  }
  expect_failures = [powerplatform_managed_solution.deployments]
}

run "reject_three_part_version" {
  command = plan
  module { source = "./modules/power-platform/solutions" }
  variables {
    deployments = {
      "SampleSolution/test" = merge(var.deployments["SampleSolution/test"], { version = "1.0.2" })
    }
  }
  expect_failures = [var.deployments]
}

run "reject_unpacked_folder" {
  command = plan
  module { source = "./modules/power-platform/solutions" }
  variables {
    deployments = {
      "SampleSolution/test" = merge(var.deployments["SampleSolution/test"], { file = "../solutions/SampleSolution" })
    }
  }
  expect_failures = [var.deployments]
}
