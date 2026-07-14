%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r/unicode15[.]ex$/]
      }
    }
  ]
}
