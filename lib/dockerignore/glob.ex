defmodule Dockerignore.Glob do
  @moduledoc false

  alias Dockerignore.{Unicode15, UTF8}

  @max_repeat 1_000
  @open_paren 40
  @close_paren 41
  @star 42
  @plus 43
  @question 63
  @open_bracket 91
  @backslash 92
  @close_bracket 93
  @caret 94
  @dollar 36
  @open_brace 123
  @close_brace 125
  @pipe 124
  @dash 45
  @colon 58
  @comma 44

  @posix_classes %{
    "alnum" => :alnum,
    "alpha" => :alpha,
    "ascii" => :ascii,
    "blank" => :blank,
    "cntrl" => :cntrl,
    "digit" => :digit,
    "graph" => :graph,
    "lower" => :lower,
    "print" => :print,
    "punct" => :punct,
    "space" => :space,
    "upper" => :upper,
    "word" => :word,
    "xdigit" => :xdigit
  }

  @type t :: %{start: non_neg_integer(), states: tuple()}

  @spec compile(binary()) :: {:ok, t()} | {:error, :invalid_pattern}
  def compile(regex_source) when is_binary(regex_source) do
    with {:ok, runes} <- UTF8.decode_strict(regex_source),
         {:ok, ast, []} <- parse_expression(runes),
         {:ok, program} <- build_program(ast) do
      {:ok, program}
    else
      _ -> {:error, :invalid_pattern}
    end
  rescue
    _ -> {:error, :invalid_pattern}
  end

  @spec match?(t(), binary()) :: boolean()
  def match?(%{start: start, states: states}, path) when is_binary(path) do
    characters = path |> UTF8.decode_lossy() |> List.to_tuple()
    run(states, start, characters, 0, tuple_size(characters), MapSet.new())
  end

  # Parser

  defp parse_expression(tokens), do: parse_alternation(tokens, [])

  defp parse_alternation(tokens, branches) do
    with {:ok, branch, rest} <- parse_concatenation(tokens, []) do
      case rest do
        [@pipe | rest] -> parse_alternation(rest, [branch | branches])
        _ -> {:ok, alternate(Enum.reverse([branch | branches])), rest}
      end
    end
  end

  defp parse_concatenation([], expressions), do: {:ok, concatenate(Enum.reverse(expressions)), []}

  defp parse_concatenation([next | _] = tokens, expressions)
       when next == @pipe or next == @close_paren do
    {:ok, concatenate(Enum.reverse(expressions)), tokens}
  end

  defp parse_concatenation(tokens, expressions) do
    with {:ok, expression, rest} <- parse_atom(tokens),
         {:ok, expression, rest} <- parse_postfix(expression, rest) do
      parse_concatenation(rest, [expression | expressions])
    end
  end

  defp parse_atom([@open_paren | rest]) do
    case parse_expression(rest) do
      {:ok, expression, [@close_paren | rest]} -> {:ok, expression, rest}
      _ -> :error
    end
  end

  defp parse_atom([@open_bracket | rest]), do: parse_class(rest)
  defp parse_atom([@backslash | rest]), do: parse_escape(rest, :outside)
  defp parse_atom([@caret | rest]), do: {:ok, {:assert, :begin_text}, rest}
  defp parse_atom([@dollar | rest]), do: {:ok, {:assert, :end_text}, rest}
  defp parse_atom([46 | rest]), do: {:ok, {:any, :not_newline}, rest}

  # Go treats a well-formed {n...} at an atom boundary as a repetition with a
  # missing operand, while malformed brace text is an ordinary literal.
  defp parse_atom([@open_brace | rest] = tokens) do
    case counted_quantifier(tokens) do
      :none -> {:ok, {:literal, @open_brace}, rest}
      _ -> :error
    end
  end

  defp parse_atom([next | _]) when next in [@star, @plus, @question], do: :error
  defp parse_atom([codepoint | rest]), do: {:ok, {:literal, codepoint}, rest}

  defp parse_postfix(expression, tokens) do
    case quantifier(tokens) do
      :none ->
        {:ok, expression, tokens}

      {:error, _reason} ->
        :error

      {:ok, min, max, rest} ->
        {rest, _lazy?} = take_lazy(rest)
        repeated = {:repeat, expression, min, max}

        cond do
          not valid_repeat?(repeated, min, max) ->
            :error

          repeat_follows?(rest) ->
            :error

          true ->
            {:ok, repeated, rest}
        end
    end
  end

  defp quantifier([@star | rest]), do: {:ok, 0, :infinity, rest}
  defp quantifier([@plus | rest]), do: {:ok, 1, :infinity, rest}
  defp quantifier([@question | rest]), do: {:ok, 0, 1, rest}
  defp quantifier([@open_brace | _] = tokens), do: counted_quantifier(tokens)
  defp quantifier(_tokens), do: :none

  defp counted_quantifier([@open_brace | rest]) do
    {digits, rest} = take_digits(rest, [])

    case repeat_count(digits) do
      {:ok, min} -> counted_upper_bound(min, rest)
      :none -> :none
    end
  end

  defp counted_upper_bound(min, [@close_brace | rest]), do: validate_counted(min, min, rest)

  defp counted_upper_bound(min, [@comma, @close_brace | rest]),
    do: validate_counted(min, :infinity, rest)

  defp counted_upper_bound(min, [@comma | rest]) do
    {digits, rest} = take_digits(rest, [])

    case repeat_count(digits) do
      {:ok, max} -> counted_closing_brace(min, max, rest)
      :none -> :none
    end
  end

  defp counted_upper_bound(_min, _rest), do: :none

  defp counted_closing_brace(min, max, [@close_brace | rest]),
    do: validate_counted(min, max, rest)

  defp counted_closing_brace(_min, _max, _rest), do: :none

  defp validate_counted(min, max, _rest)
       when min > @max_repeat or (is_integer(max) and max > @max_repeat) or
              (is_integer(max) and min > max),
       do: {:error, :invalid_count}

  defp validate_counted(min, max, rest), do: {:ok, min, max, rest}

  defp take_digits([digit | rest], digits) when digit in 48..57,
    do: take_digits(rest, [digit | digits])

  defp take_digits(rest, digits), do: {Enum.reverse(digits), rest}
  defp repeat_count([]), do: :none

  defp repeat_count(digits) do
    if leading_zero?(digits), do: :none, else: {:ok, decimal_value(digits)}
  end

  defp leading_zero?([48, _ | _]), do: true
  defp leading_zero?(_digits), do: false

  defp decimal_value(digits),
    do: Enum.reduce(digits, 0, fn digit, value -> value * 10 + digit - 48 end)

  defp take_lazy([@question | rest]), do: {rest, true}
  defp take_lazy(rest), do: {rest, false}

  defp repeat_follows?(tokens) do
    case quantifier(tokens) do
      {:ok, _min, _max, _rest} -> true
      _ -> false
    end
  end

  defp valid_repeat?(expression, min, max) do
    if min >= 2 or (is_integer(max) and max >= 2) do
      repeat_is_valid?(expression, @max_repeat)
    else
      true
    end
  end

  defp repeat_is_valid?({:repeat, expression, min, max}, budget) do
    multiplier = if max == :infinity, do: min, else: max

    cond do
      multiplier == 0 -> true
      multiplier > budget -> false
      true -> repeat_is_valid?(expression, div(budget, multiplier))
    end
  end

  defp repeat_is_valid?({:concat, expressions}, budget),
    do: Enum.all?(expressions, &repeat_is_valid?(&1, budget))

  defp repeat_is_valid?({:alt, expressions}, budget),
    do: Enum.all?(expressions, &repeat_is_valid?(&1, budget))

  defp repeat_is_valid?(_expression, _budget), do: true

  # Character classes and escapes

  defp parse_class(tokens) do
    {negated?, tokens} =
      case tokens do
        [@caret | rest] -> {true, rest}
        _ -> {false, tokens}
      end

    parse_class_items(tokens, true, [], negated?)
  end

  defp parse_class_items([], _first?, _members, _negated?), do: :error

  defp parse_class_items([@close_bracket | rest], false, members, negated?) do
    {:ok, {:class, negated?, Enum.reverse(members)}, rest}
  end

  defp parse_class_items(tokens, _first?, members, negated?) do
    with {:ok, item, rest} <- parse_class_item(tokens),
         {:ok, item, rest} <- maybe_range(item, rest) do
      parse_class_items(rest, false, [class_member(item) | members], negated?)
    else
      _ -> :error
    end
  end

  defp maybe_range({:literal, first}, [@dash | rest]) do
    case rest do
      [] ->
        {:ok, {:literal, first}, [@dash]}

      [@close_bracket | _] ->
        {:ok, {:literal, first}, [@dash | rest]}

      _ ->
        with {:ok, {:literal, last}, rest} <- parse_class_character(rest),
             true <- first <= last do
          {:ok, {:range, first, last}, rest}
        else
          _ -> :error
        end
    end
  end

  defp maybe_range(item, rest), do: {:ok, item, rest}

  defp class_member({:member, member}), do: member
  defp class_member(member), do: member

  defp parse_class_item([@open_bracket, @colon | rest]) do
    case take_posix_name(rest, []) do
      {:ok, name, rest} ->
        with {:ok, member} <- posix_member(name) do
          {:ok, {:member, member}, rest}
        end

      {:error, :unterminated} ->
        {:ok, {:literal, @open_bracket}, [@colon | rest]}

      {:error, :empty} ->
        :error
    end
  end

  defp parse_class_item([@backslash | rest]), do: parse_escape(rest, :class)
  defp parse_class_item([codepoint | rest]), do: {:ok, {:literal, codepoint}, rest}

  defp parse_class_character([@backslash | rest]) do
    case parse_escape(rest, :class) do
      {:ok, {:literal, _codepoint} = literal, rest} -> {:ok, literal, rest}
      _ -> :error
    end
  end

  defp parse_class_character([codepoint | rest]), do: {:ok, {:literal, codepoint}, rest}

  defp take_posix_name([@colon, @close_bracket | _rest], []), do: {:error, :empty}

  defp take_posix_name([@colon, @close_bracket | rest], name) do
    {:ok, codepoints_to_binary(Enum.reverse(name)), rest}
  end

  defp take_posix_name([codepoint | rest], name), do: take_posix_name(rest, [codepoint | name])
  defp take_posix_name([], _name), do: {:error, :unterminated}

  defp posix_member(<<@caret, name::binary>>) do
    with {:ok, member} <- posix_member(name), do: {:ok, {:not, member}}
  end

  defp posix_member(name) do
    case Map.fetch(@posix_classes, name) do
      {:ok, class} -> {:ok, {:ascii, class}}
      :error -> :error
    end
  end

  defp parse_escape([], _context), do: :error

  defp parse_escape([81 | rest], :outside) do
    {quoted, rest} = take_quoted(rest, [])
    {:ok, concatenate(Enum.map(quoted, &{:literal, &1})), rest}
  end

  defp parse_escape([65 | rest], :outside), do: {:ok, {:assert, :begin_text}, rest}
  defp parse_escape([122 | rest], :outside), do: {:ok, {:assert, :end_text}, rest}
  defp parse_escape([98 | rest], :outside), do: {:ok, {:assert, :word_boundary}, rest}
  defp parse_escape([66 | rest], :outside), do: {:ok, {:assert, :not_word_boundary}, rest}

  defp parse_escape([kind | rest], context) when kind in [100, 68, 115, 83, 119, 87] do
    member =
      case kind do
        100 -> {:ascii, :digit}
        68 -> {:not, {:ascii, :digit}}
        115 -> {:ascii, :perl_space}
        83 -> {:not, {:ascii, :perl_space}}
        119 -> {:ascii, :word}
        87 -> {:not, {:ascii, :word}}
      end

    escaped_member(member, context, rest)
  end

  defp parse_escape([kind | rest], context) when kind in [112, 80],
    do: parse_unicode_escape(kind, rest, context)

  defp parse_escape([120 | rest], context), do: parse_hex_escape(rest, context)
  defp parse_escape([48 | rest], context), do: parse_octal_escape(rest, [48], context)

  defp parse_escape([first, second | rest], context)
       when first in 49..55 and second in 48..55,
       do: parse_octal_escape(rest, [first, second], context)

  defp parse_escape([first | _rest], _context) when first in 49..55, do: :error

  defp parse_escape([kind | rest], context) when kind in [97, 102, 110, 114, 116, 118] do
    escaped_literal(control_codepoint(kind), context, rest)
  end

  defp parse_escape([escaped | rest], context) do
    if escaped < 128 and not ascii_alphanumeric?(escaped) do
      escaped_literal(escaped, context, rest)
    else
      :error
    end
  end

  defp parse_unicode_escape(kind, [@open_brace | rest], context) do
    case take_until_close_brace(rest, []) do
      {:ok, name, rest} -> unicode_member(kind, codepoints_to_binary(name), context, rest)
      :error -> :error
    end
  end

  defp parse_unicode_escape(kind, [name | rest], context),
    do: unicode_member(kind, codepoints_to_binary([name]), context, rest)

  defp parse_unicode_escape(_kind, [], _context), do: :error

  defp take_until_close_brace([@close_brace | _rest], []), do: :error
  defp take_until_close_brace([@close_brace | rest], name), do: {:ok, Enum.reverse(name), rest}

  defp take_until_close_brace([codepoint | rest], name),
    do: take_until_close_brace(rest, [codepoint | name])

  defp take_until_close_brace([], _name), do: :error

  defp unicode_member(kind, <<@caret, name::binary>>, context, rest),
    do: unicode_member(flip_property(kind), name, context, rest)

  defp unicode_member(kind, name, context, rest) do
    case Unicode15.lookup(name) do
      {:ok, ranges, inverted?} ->
        member = {:unicode, ranges, inverted?}
        member = if kind == 80, do: {:not, member}, else: member
        escaped_member(member, context, rest)

      :error ->
        :error
    end
  end

  defp flip_property(112), do: 80
  defp flip_property(80), do: 112

  defp parse_hex_escape([@open_brace | rest], context) do
    with {:ok, digits, rest} <- take_braced_hex(rest, []),
         {:ok, value} <- hexadecimal_value(digits) do
      escaped_literal(value, context, rest)
    end
  end

  defp parse_hex_escape([first, second | rest], context) do
    with {:ok, value} <- hexadecimal_value([first, second]) do
      escaped_literal(value, context, rest)
    end
  end

  defp parse_hex_escape(_rest, _context), do: :error

  defp take_braced_hex([@close_brace | _rest], []), do: :error
  defp take_braced_hex([@close_brace | rest], digits), do: {:ok, Enum.reverse(digits), rest}
  defp take_braced_hex([digit | rest], digits), do: take_braced_hex(rest, [digit | digits])
  defp take_braced_hex([], _digits), do: :error

  defp hexadecimal_value(digits) do
    digits
    |> Enum.reduce_while(0, &reduce_hex_digit/2)
    |> hexadecimal_literal()
  end

  defp reduce_hex_digit(digit, value) do
    case hex_value(digit) do
      :error -> {:halt, :error}
      hexadecimal -> {:cont, value * 16 + hexadecimal}
    end
  end

  defp hexadecimal_literal(value) when is_integer(value) and value <= 0x10FFFF, do: {:ok, value}
  defp hexadecimal_literal(_value), do: :error

  defp parse_octal_escape(rest, digits, context) do
    {digits, rest} = take_octal_digits(rest, digits)
    value = Enum.reduce(digits, 0, fn digit, value -> value * 8 + digit - 48 end)
    escaped_literal(value, context, rest)
  end

  defp take_octal_digits([digit | rest], digits) when digit in 48..55 and length(digits) < 3,
    do: take_octal_digits(rest, digits ++ [digit])

  defp take_octal_digits(rest, digits), do: {digits, rest}

  defp escaped_member(member, :outside, rest), do: {:ok, {:class, false, [member]}, rest}
  defp escaped_member(member, :class, rest), do: {:ok, {:member, member}, rest}
  defp escaped_literal(codepoint, :outside, rest), do: {:ok, {:literal, codepoint}, rest}
  defp escaped_literal(codepoint, :class, rest), do: {:ok, {:literal, codepoint}, rest}

  defp take_quoted([@backslash, 69 | rest], quoted), do: {Enum.reverse(quoted), rest}
  defp take_quoted([codepoint | rest], quoted), do: take_quoted(rest, [codepoint | quoted])
  defp take_quoted([], quoted), do: {Enum.reverse(quoted), []}

  defp control_codepoint(97), do: 7
  defp control_codepoint(102), do: 12
  defp control_codepoint(110), do: 10
  defp control_codepoint(114), do: 13
  defp control_codepoint(116), do: 9
  defp control_codepoint(118), do: 11

  defp ascii_alphanumeric?(codepoint),
    do: codepoint in 48..57 or codepoint in 65..90 or codepoint in 97..122

  defp hex_value(codepoint) when codepoint in 48..57, do: codepoint - 48
  defp hex_value(codepoint) when codepoint in 65..70, do: codepoint - 65 + 10
  defp hex_value(codepoint) when codepoint in 97..102, do: codepoint - 97 + 10
  defp hex_value(_codepoint), do: :error
  defp codepoints_to_binary(codepoints), do: :unicode.characters_to_binary(codepoints)

  # Thompson compiler

  defp build_program(ast) do
    with {fragment, compiler} <- compile_ast(ast, %{next_id: 0, states: %{}}),
         {match, compiler} <- new_state(compiler, :match) do
      compiler = patch(compiler, elem(fragment, 1), match)

      states =
        0..(compiler.next_id - 1)
        |> Enum.map(&Map.fetch!(compiler.states, &1))
        |> List.to_tuple()

      {:ok, %{start: elem(fragment, 0), states: states}}
    end
  end

  defp compile_ast(:empty, compiler) do
    {state, compiler} = new_state(compiler, {:epsilon, nil})
    {{state, [{state, :next}]}, compiler}
  end

  defp compile_ast({:literal, codepoint}, compiler) do
    {state, compiler} = new_state(compiler, {:consume, {:literal, codepoint}, nil})
    {{state, [{state, :next}]}, compiler}
  end

  defp compile_ast({:any, kind}, compiler) do
    {state, compiler} = new_state(compiler, {:consume, {:any, kind}, nil})
    {{state, [{state, :next}]}, compiler}
  end

  defp compile_ast({:class, negated?, members}, compiler) do
    {state, compiler} = new_state(compiler, {:consume, {:class, negated?, members}, nil})
    {{state, [{state, :next}]}, compiler}
  end

  defp compile_ast({:assert, assertion}, compiler) do
    {state, compiler} = new_state(compiler, {:assert, assertion, nil})
    {{state, [{state, :next}]}, compiler}
  end

  defp compile_ast({:concat, expressions}, compiler), do: compile_sequence(expressions, compiler)

  defp compile_ast({:alt, expressions}, compiler), do: compile_alternation(expressions, compiler)

  defp compile_ast({:repeat, expression, 0, :infinity}, compiler),
    do: compile_star(expression, compiler)

  defp compile_ast({:repeat, expression, 1, :infinity}, compiler),
    do: compile_plus(expression, compiler)

  defp compile_ast({:repeat, expression, 0, 1}, compiler),
    do: compile_question(expression, compiler)

  defp compile_ast({:repeat, expression, min, max}, compiler),
    do: compile_counted(expression, min, max, compiler)

  defp compile_sequence([], compiler), do: compile_ast(:empty, compiler)

  defp compile_sequence([expression | rest], compiler) do
    {fragment, compiler} = compile_ast(expression, compiler)

    Enum.reduce(rest, {fragment, compiler}, fn expression, {left, compiler} ->
      {right, compiler} = compile_ast(expression, compiler)
      compiler = patch(compiler, elem(left, 1), elem(right, 0))
      {{elem(left, 0), elem(right, 1)}, compiler}
    end)
  end

  defp compile_alternation([expression], compiler), do: compile_ast(expression, compiler)

  defp compile_alternation([expression | rest], compiler) do
    {left, compiler} = compile_ast(expression, compiler)
    {right, compiler} = compile_alternation(rest, compiler)
    {state, compiler} = new_state(compiler, {:split, elem(left, 0), elem(right, 0)})
    {{state, elem(left, 1) ++ elem(right, 1)}, compiler}
  end

  defp compile_alternation([], compiler), do: compile_ast(:empty, compiler)

  defp compile_star(expression, compiler) do
    {fragment, compiler} = compile_ast(expression, compiler)
    {state, compiler} = new_state(compiler, {:split, elem(fragment, 0), nil})
    compiler = patch(compiler, elem(fragment, 1), state)
    {{state, [{state, :right}]}, compiler}
  end

  defp compile_plus(expression, compiler) do
    {fragment, compiler} = compile_ast(expression, compiler)
    {state, compiler} = new_state(compiler, {:split, elem(fragment, 0), nil})
    compiler = patch(compiler, elem(fragment, 1), state)
    {{elem(fragment, 0), [{state, :right}]}, compiler}
  end

  defp compile_question(expression, compiler) do
    {fragment, compiler} = compile_ast(expression, compiler)
    {state, compiler} = new_state(compiler, {:split, elem(fragment, 0), nil})
    {{state, elem(fragment, 1) ++ [{state, :right}]}, compiler}
  end

  defp compile_counted(expression, min, max, compiler) do
    {fragment, compiler} = compile_many(expression, min, compiler)

    case max do
      :infinity ->
        {tail, compiler} = compile_star(expression, compiler)
        compiler = patch(compiler, elem(fragment, 1), elem(tail, 0))
        {{elem(fragment, 0), elem(tail, 1)}, compiler}

      max ->
        compile_optional(expression, max - min, fragment, compiler)
    end
  end

  defp compile_optional(_expression, 0, fragment, compiler), do: {fragment, compiler}

  defp compile_optional(expression, count, fragment, compiler) do
    Enum.reduce(1..count, {fragment, compiler}, fn _, {left, compiler} ->
      {right, compiler} = compile_question(expression, compiler)
      compiler = patch(compiler, elem(left, 1), elem(right, 0))
      {{elem(left, 0), elem(right, 1)}, compiler}
    end)
  end

  defp compile_many(_expression, 0, compiler), do: compile_ast(:empty, compiler)

  defp compile_many(expression, count, compiler) do
    compile_sequence(List.duplicate(expression, count), compiler)
  end

  defp new_state(%{next_id: id, states: states} = compiler, node) do
    {id, %{compiler | next_id: id + 1, states: Map.put(states, id, node)}}
  end

  defp patch(compiler, outs, target) do
    Enum.reduce(outs, compiler, fn {state, field}, compiler ->
      node = Map.fetch!(compiler.states, state)
      node = patch_node(node, field, target)
      %{compiler | states: Map.put(compiler.states, state, node)}
    end)
  end

  defp patch_node({:epsilon, _next}, :next, target), do: {:epsilon, target}
  defp patch_node({:consume, predicate, _next}, :next, target), do: {:consume, predicate, target}
  defp patch_node({:assert, assertion, _next}, :next, target), do: {:assert, assertion, target}
  defp patch_node({:split, _left, right}, :left, target), do: {:split, target, right}
  defp patch_node({:split, left, _right}, :right, target), do: {:split, left, target}

  # NFA execution

  defp run(states, start, characters, position, length, active) do
    active = active |> MapSet.put(start) |> closure(states, characters, position, length)

    cond do
      Enum.any?(active, &(elem(states, &1) == :match)) ->
        true

      position == length ->
        false

      true ->
        active = consume(active, states, elem(characters, position))
        run(states, start, characters, position + 1, length, active)
    end
  end

  defp consume(active, states, codepoint) do
    Enum.reduce(active, MapSet.new(), fn state, next ->
      consume_state(next, elem(states, state), codepoint)
    end)
  end

  defp consume_state(next, {:consume, predicate, target}, codepoint) do
    if predicate_matches?(predicate, codepoint), do: MapSet.put(next, target), else: next
  end

  defp consume_state(next, _state, _codepoint), do: next

  defp closure(active, states, characters, position, length) do
    close(MapSet.to_list(active), active, states, characters, position, length)
  end

  defp close([], active, _states, _characters, _position, _length), do: active

  defp close([state | pending], active, states, characters, position, length) do
    {active, pending} =
      case elem(states, state) do
        {:epsilon, target} ->
          add_state(active, pending, target)

        {:split, left, right} ->
          active |> add_state(pending, left) |> add_state(right)

        {:assert, assertion, target} ->
          if assertion_matches?(assertion, characters, position, length) do
            add_state(active, pending, target)
          else
            {active, pending}
          end

        _ ->
          {active, pending}
      end

    close(pending, active, states, characters, position, length)
  end

  defp add_state({active, pending}, target), do: add_state(active, pending, target)

  defp add_state(active, pending, target) do
    if MapSet.member?(active, target) do
      {active, pending}
    else
      {MapSet.put(active, target), [target | pending]}
    end
  end

  defp assertion_matches?(:begin_text, _characters, 0, _length), do: true
  defp assertion_matches?(:begin_text, _characters, _position, _length), do: false
  defp assertion_matches?(:end_text, _characters, position, length), do: position == length

  defp assertion_matches?(assertion, characters, position, length)
       when assertion in [:word_boundary, :not_word_boundary] do
    left? = position > 0 and ascii_member?(:word, elem(characters, position - 1))
    right? = position < length and ascii_member?(:word, elem(characters, position))
    boundary? = left? != right?
    if assertion == :word_boundary, do: boundary?, else: not boundary?
  end

  defp predicate_matches?({:literal, expected}, codepoint), do: expected == codepoint
  defp predicate_matches?({:any, :not_newline}, codepoint), do: codepoint != 10

  defp predicate_matches?({:class, negated?, members}, codepoint) do
    matched? = Enum.any?(members, &member_matches?(&1, codepoint))
    if negated?, do: not matched?, else: matched?
  end

  defp member_matches?({:literal, expected}, codepoint), do: expected == codepoint
  defp member_matches?({:range, first, last}, codepoint), do: codepoint in first..last
  defp member_matches?({:ascii, class}, codepoint), do: ascii_member?(class, codepoint)

  defp member_matches?({:unicode, ranges, inverted?}, codepoint) do
    matched? = Unicode15.member?(ranges, codepoint)
    if inverted?, do: not matched?, else: matched?
  end

  defp member_matches?({:not, member}, codepoint), do: not member_matches?(member, codepoint)

  defp ascii_member?(:ascii, codepoint), do: codepoint <= 0x7F

  defp ascii_member?(:alnum, codepoint),
    do: ascii_member?(:alpha, codepoint) or ascii_member?(:digit, codepoint)

  defp ascii_member?(:alpha, codepoint),
    do: ascii_member?(:lower, codepoint) or ascii_member?(:upper, codepoint)

  defp ascii_member?(:blank, codepoint), do: codepoint in [9, 32]
  defp ascii_member?(:cntrl, codepoint), do: codepoint in 0..31 or codepoint == 127
  defp ascii_member?(:digit, codepoint), do: codepoint in 48..57
  defp ascii_member?(:graph, codepoint), do: codepoint in 33..126
  defp ascii_member?(:lower, codepoint), do: codepoint in 97..122
  defp ascii_member?(:print, codepoint), do: codepoint in 32..126

  defp ascii_member?(:punct, codepoint),
    do: codepoint in 33..126 and not ascii_member?(:alnum, codepoint)

  defp ascii_member?(:perl_space, codepoint), do: codepoint in [9, 10, 12, 13, 32]
  defp ascii_member?(:space, codepoint), do: codepoint in [9, 10, 11, 12, 13, 32]
  defp ascii_member?(:upper, codepoint), do: codepoint in 65..90
  defp ascii_member?(:word, codepoint), do: ascii_member?(:alnum, codepoint) or codepoint == 95

  defp ascii_member?(:xdigit, codepoint),
    do: codepoint in 48..57 or codepoint in 65..70 or codepoint in 97..102

  defp concatenate([]), do: :empty
  defp concatenate([expression]), do: expression
  defp concatenate(expressions), do: {:concat, expressions}
  defp alternate([expression]), do: expression
  defp alternate(expressions), do: {:alt, expressions}
end
