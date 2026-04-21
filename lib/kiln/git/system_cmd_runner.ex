defmodule Kiln.Git.SystemCmdRunner do
  @moduledoc false
  @behaviour Kiln.Git.Cmd

  @impl Kiln.Git.Cmd
  def run_git(argv, opts \\ []) when is_list(argv) do
    {cd, cmd_opts} = Keyword.pop(opts, :cd)
    cmd_opts = Keyword.put_new(cmd_opts, :stderr_to_stdout, true)

    cmd_opts =
      if cd do
        Keyword.put(cmd_opts, :cd, cd)
      else
        cmd_opts
      end

    case System.cmd("git", argv, cmd_opts) do
      {out, 0} ->
        {:ok, out}

      {out, code} ->
        {:error,
         %{
           exit_status: code,
           stdout: out,
           stderr: out
         }}
    end
  end
end
