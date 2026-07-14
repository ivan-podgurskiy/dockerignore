{fixture, _binding} = Code.eval_file("test/fixtures/patternmatcher_v0_6_1.exs")

expected_result = fn
  :error -> "E"
  true -> "1"
  false -> "0"
end

cases =
  fixture.matches
  |> Enum.with_index()
  |> Enum.map(fn {%{source: source, path: path, ignored: ignored}, index} ->
    %{
      id: "upstream-decision-#{index}",
      source: source,
      path: path,
      expected: expected_result.(ignored)
    }
  end)
  |> Kernel.++(
    fixture.errors
    |> Enum.with_index()
    |> Enum.map(fn {%{source: source}, index} ->
      %{id: "upstream-error-#{index}", source: source, path: "", expected: "E"}
    end)
  )
  |> Kernel.++(
    Enum.map(fixture.differential, fn %{id: id, source: source, path: path, expected: expected} ->
      %{
        id: "final-review-#{id}",
        source: source,
        path: path,
        expected: expected_result.(expected)
      }
    end)
  )

decision_count = Enum.count(cases, &(&1.expected != "E"))
error_count = length(cases) - decision_count

temporary_fixture =
  Path.join(
    System.tmp_dir!(),
    "dockerignore-patternmatcher-oracle-#{System.unique_integer([:positive])}.tsv"
  )

try do
  rows =
    cases
    |> Enum.map_join("\n", fn %{id: id, source: source, path: path} ->
      [id, Base.encode64(source), Base.encode64(path)]
      |> Enum.join("\t")
    end)

  File.write!(temporary_fixture, rows <> "\n")

  elixir_results =
    cases
    |> Map.new(fn %{id: id, source: source, path: path} ->
      result =
        case Dockerignore.compile(source) do
          {:ok, matcher} -> if Dockerignore.ignored?(matcher, path), do: "1", else: "0"
          {:error, error} -> "E:#{Exception.message(error)}"
        end

      {id, result}
    end)

  {output, exit_status} = System.cmd("go", ["run", ".", temporary_fixture], cd: "scripts/oracle")

  if exit_status != 0 do
    raise "Go oracle failed with exit status #{exit_status}: #{output}"
  end

  go_rows =
    output
    |> String.split("\n", trim: true)

  go_results =
    go_rows
    |> Map.new(fn row ->
      case String.split(row, "\t", parts: 2) do
        [id, result] -> {id, result}
        _ -> raise "invalid Go oracle output: #{inspect(row)}"
      end
    end)

  expected_ids =
    cases
    |> MapSet.new(& &1.id)

  protocol_mismatches =
    if length(go_rows) == map_size(go_results) do
      []
    else
      ["Go oracle emitted duplicate result IDs"]
    end

  result_category = fn
    "1" -> "1"
    "0" -> "0"
    "E:" <> _message -> "E"
    nil -> "missing"
    _ -> "invalid"
  end

  mismatches =
    cases
    |> Enum.flat_map(fn %{id: id, source: source, path: path, expected: expected} ->
      elixir = Map.fetch!(elixir_results, id)
      go = Map.get(go_results, id)
      elixir_category = result_category.(elixir)
      go_category = result_category.(go)

      if expected == elixir_category and expected == go_category do
        []
      else
        [
          "id=#{id} source=#{inspect(source)} path=#{inspect(path)} expected=#{expected} " <>
            "elixir=#{inspect(elixir)} (#{elixir_category}) go=#{inspect(go)} (#{go_category})"
        ]
      end
    end)
    |> Kernel.++(
      go_results
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(expected_ids, &1))
      |> Enum.map(&"unexpected Go oracle result id=#{&1}")
    )
    |> Kernel.++(protocol_mismatches)

  if mismatches == [] do
    IO.puts("oracle: #{decision_count} decisions, #{error_count} errors, 0 mismatches")
  else
    raise Enum.join(mismatches, "\n")
  end
after
  File.rm(temporary_fixture)
end
