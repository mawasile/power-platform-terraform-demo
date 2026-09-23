# Managed solution packages promoted out of dev, keyed by the solution unique name.
# Paths are relative to the repository root, and version must match the package.
# The file name stays version free: replace the zip and raise version together.
# Non-secret environment variable values live here; prod's bal_MagicNumber is
# injected at deploy time from the MAGIC_NUMBER_PROD GitHub Environment secret.
solutions = {
  TerrraformExampleSolution = {
    version      = "1.0.0.3"
    file         = "solutions/TerrraformExampleSolution_managed.zip"
    environments = ["test", "prod"]

    environment_variables = {
      test = { bal_MagicNumber = "42" }
    }
  }
}
