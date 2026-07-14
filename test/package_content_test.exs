defmodule Dockerignore.PackageContentTest do
  use ExUnit.Case, async: true

  test "packages the generated Unicode attribution without development tooling" do
    package = Dockerignore.MixProject.project()[:package]
    files = package[:files]
    extras = Dockerignore.MixProject.project()[:docs][:extras]

    assert "lib" in files
    assert "LICENSES/BSD-3-Clause-Go.txt" in files
    assert "LICENSES/BSD-3-Clause-Go.txt" in extras
    refute "scripts" in files
    refute "test" in files
    refute "_build" in files
    refute "deps" in files

    notice = File.read!(Path.expand("../NOTICE", __DIR__))
    assert notice =~ ~r/Go\s+Authors/
    assert notice =~ "BSD-3-Clause"
    assert notice =~ "Unicode 15.0.0"
  end
end
