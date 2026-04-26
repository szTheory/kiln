# Phase 8 — Pattern Map

Analog files and excerpts for executors — read before editing.

| Planned surface | Analog (read_first) | Pattern |
|-----------------|---------------------|---------|
| New LiveViews | `lib/kiln_web/live/run_board_live.ex`, `lib/kiln_web/live/cost_live.ex` | `<Layouts.app flash={@flash} current_scope={@current_scope}>`, streams, `allow?` stub |
| Router + session | `lib/kiln_web/router.ex` | `live_session :default, on_mount: [{KilnWeb.LiveScope, :default}]` |
| Spec domain | `lib/kiln/specs.ex`, `lib/kiln/specs/spec.ex` | `Repo`, `Ecto.Changeset`, append-only revisions for promoted specs |
| HTTP client | `mix.exs` (`:req`) + existing adapter modules | Named Finch pools per provider where applicable |
| Audit | `lib/kiln/audit.ex` (or equivalent) | Insert `Audit.Event` in same transaction as state change |
| External intents | `lib/kiln/external_operations.ex` (if present) or Phase 1 patterns | Two-phase intent keys |
| Notifications | `lib/kiln/notifications.ex` | Reuse for block desktop notify |
| Model health data | `lib/kiln/model_registry.ex` (verify path in tree) | Poll-friendly read APIs for provider cards |
| Boot vs operator | `lib/kiln/boot_checks.ex`, `lib/kiln_web/plugs/scope.ex` | Separate concerns; plug allowlists |

**Anti-patterns:** Inbox code in `Kiln.Intents`; new `/ops/*` domain routes; ticker subscribed from layout on every page.

## PATTERN MAPPING COMPLETE
