defmodule Mix.Tasks.Phx.Gen.Schema do
  @shortdoc "Generates an Ecto schema and migration file"

  @moduledoc """
  Generates an Ecto schema and migration.

      mix phx.gen.schema Blog.Post blog_posts title:string views:integer

  The first argument is the schema module followed by its plural
  name (used as the table name).

  The generated schema above will contain:

    * a schema file in lib/my_app/blog/post.ex, with a `blog_posts` table.
    * a migration file for the repository

  The generated migration can be skipped with `--no-migration`.

  ## Attributes

  The resource fields are given using `name:type` syntax
  where type are the types supported by Ecto. Omitting
  the type makes it default to `:string`:

      mix phx.gen.schema Blog.Post blog_posts title views:integer

  The following types are supported:

  #{for attr <- Mix.Phoenix.Schema.valid_types(), do: "  * `#{inspect attr}`\n"}
    * `:datetime` - An alias for `:naive_datetime`

  The generator also supports references, which we will properly
  associate the given column to the primary key column of the
  referenced table:

      mix phx.gen.schema Blog.Post blog_posts title user_id:references:blog_users

  This will result in a migration with an `:integer` column
  of `:user_id` and create an index.

  Furthermore an array type can also be given if it is
  supported by your database, although it requires the
  type of the underlying array element to be given too:

      mix phx.gen.schema Blog.Post blog_posts tags:array:string

  Unique columns can be automatically generated by using:

      mix phx.gen.schema Blog.Post blog_posts title:unique unique_int:integer:unique

  If no data type is given, it defaults to a string.

  ## table

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For example:

      mix phx.gen.schema Blog.Post posts --table cms_posts

  ## binary_id

  Generated migration can use `binary_id` for schema's primary key
  and its references with option `--binary-id`.

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of your application. These are the defaults:

      config :your_app, :generators,
        migration: true,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration or `--migration` to force generation of the migration.
  """
  use Mix.Task

  alias Mix.Phoenix.Schema

  @switches [migration: :boolean, binary_id: :boolean, table: :string,
             web: :string]

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.schema can only be run inside an application directory"
    end

    schema = build(args, [])
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(schema)

    schema
    |> copy_new_files(paths, schema: schema)
    |> print_shell_instructions()
  end

  defp prompt_for_conflicts(schema) do
    schema
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  def build(args, parent_opts, help \\ __MODULE__) do
    {schema_opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    [schema_name, plural | attrs] = validate_args!(parsed, help)
    opts = Keyword.merge(parent_opts, schema_opts)

    schema = Schema.new(schema_name, plural, attrs, opts)
    Mix.Phoenix.check_module_name_availability!(schema.module)

    schema
  end

  def files_to_be_generated(%Schema{} = schema) do
    [{:eex, "schema.ex", schema.file}]
  end

  def copy_new_files(%Schema{} = schema, paths, binding) do
    migration =
      schema.module
      |> Module.split()
      |> tl()
      |> Module.concat()
      |> inspect()
      |> Phoenix.Naming.underscore()
      |> String.replace("/", "_")

    files = files_to_be_generated(schema)
    Mix.Phoenix.copy_from(paths,"priv/templates/phx.gen.schema", "", binding, files)

    if schema.migration? do
      Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.schema", "", binding, [
        {:eex, "migration.exs", "priv/repo/migrations/#{timestamp()}_create_#{migration}.exs"},
      ]
    end

    schema
  end

  def print_shell_instructions(%Schema{} = schema) do
    if schema.migration? do
      Mix.shell.info """

      Remember to update your repository by running migrations:

          $ mix ecto.migrate
      """
    end
  end

  def validate_args!([schema, plural | _] = args, help) do
    cond do
      not Schema.valid?(schema) ->
        help.raise_with_help "Expected the schema argument, #{inspect schema}, to be a valid module name"
      String.contains?(plural, ":") or plural != Phoenix.Naming.underscore(plural) ->
        help.raise_with_help "Expected the plural argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end
  def validate_args!(_, help) do
    help.raise_with_help "Invalid arguments"
  end

  @spec raise_with_help(String.t) :: no_return()
  def raise_with_help(msg) do
    Mix.raise """
    #{msg}

    mix phx.gen.schema and phx.gen.embedded expects both a module
    name and the plural of the generated resource followed by
    any number of attributes:

        mix phx.gen.schema Blog.Post blog_posts title:string
    """
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end
  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)
end
