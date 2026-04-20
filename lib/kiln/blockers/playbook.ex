defmodule Kiln.Blockers.Playbook do
  @moduledoc """
  Decoded playbook: YAML frontmatter map + markdown body. Produced by
  `Kiln.Blockers.PlaybookRegistry` at compile time.
  """

  defstruct [:reason, :frontmatter, :body_markdown]

  @type t :: %__MODULE__{
          reason: Kiln.Blockers.Reason.t(),
          frontmatter: map(),
          body_markdown: String.t()
        }
end

defmodule Kiln.Blockers.RenderedPlaybook do
  @moduledoc """
  Output of `Kiln.Blockers.PlaybookRegistry.render/2` — Mustache-substituted
  strings ready for terminal / LiveView / Slack consumption.
  """

  defstruct [
    :reason,
    :title,
    :severity,
    :short_message,
    :commands,
    :body_markdown,
    :next_action_on_resolve
  ]

  @type t :: %__MODULE__{
          reason: Kiln.Blockers.Reason.t(),
          title: String.t(),
          severity: String.t(),
          short_message: String.t(),
          commands: [%{label: String.t(), command: String.t()}],
          body_markdown: String.t(),
          next_action_on_resolve: String.t()
        }
end
