[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs:
    [
      "*.{heex,ex,exs}",
      "{config,lib}/**/*.{heex,ex,exs}",
      "priv/*/seeds.exs"
    ] ++
      (Path.wildcard("test/**/*.{heex,ex,exs}")
       |> Enum.reject(&String.starts_with?(&1, "test/generated/")))
]
