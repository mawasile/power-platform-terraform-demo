# Managed solution packages promoted out of dev, keyed by the solution unique name.
# Paths are relative to the repository root, and version must match the package.
# The file name stays version free: replace the zip and raise version together.
solutions = {
  TerrraformExampleSolution = {
    version      = "1.0.0.2"
    file         = "solutions/TerrraformExampleSolution_managed.zip"
    environments = ["test", "prod", "preprod"]

    # bal_MagicNumber ships as a Number definition with no packaged value.
    # preprod matches prod so it validates the same value before promotion.
    environment_variables = {
      test    = { bal_MagicNumber = "42" }
      prod    = { bal_MagicNumber = "7" }
      preprod = { bal_MagicNumber = "7" }
    }
  }
}
