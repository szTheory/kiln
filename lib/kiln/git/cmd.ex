defmodule Kiln.Git.Cmd do
  @moduledoc """
  Injectable `git` process boundary (GIT-01).

  Default implementation is `Kiln.Git.SystemCmdRunner`, which delegates to
  `System.cmd/3` with **argv as a list** (never shell-concatenated strings).
  """

  @typedoc "Normalized stderr/stdout split; when `stderr_to_stdout` is used, both may match."
  @type error_map :: %{
          required(:exit_status) => non_neg_integer(),
          required(:stderr) => String.t(),
          required(:stdout) => String.t()
        }

  @doc """
  Runs `git` with the given argv. Options are passed through to `System.cmd/3`
  except `:cd`, which sets the working directory.
  """
  @callback run_git(argv :: [String.t()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, error_map()}
end
