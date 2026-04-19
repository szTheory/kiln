# Kiln mix_audit CVE allowlist.
#
# Every entry MUST include a dated comment explaining why the CVE is accepted
# and who signed off. Format:
#
#   %{
#     id: "GHSA-xxxx-xxxx-xxxx",
#     package: "some_dep",
#     reason: "not reachable in our call graph — verified 2026-04-18 by jon",
#     added_at: ~D[2026-04-18]
#   }
#
# Empty at Phase 1 (2026-04-18) — no CVEs in locked deps.

[]
