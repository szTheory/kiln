# D-119 five-layer egress-block negative baselines — 3 vectors.
#
# Used by `test/kiln/sandboxes/egress_blocking_test.exs` (adversarial
# suite shipped in plan 03-08 Wave 4). A PASS requires each vector to
# fail with the specific REFUSED / NXDOMAIN semantics noted below.
# A mere timeout is NOT a pass — timeout = "egress is slow", REFUSED =
# "egress is blocked by a layer we control".
#
# Contract:
#   [%{
#     vector :: atom,           # test-name discriminator
#     target :: String.t(),     # hostname or IP to hit
#     dns_server :: String.t(), # for DNS probes
#     port :: pos_integer,      # for TCP probes
#     expect :: :nxdomain | :refused  # the required failure mode
#   }]

[
  %{
    vector: :dns_a_public,
    target: "google.com",
    dns_server: "1.1.1.1",
    expect: :nxdomain
  },
  %{
    vector: :dns_aaaa_public,
    target: "google.com",
    dns_server: "2606:4700:4700::1111",
    expect: :nxdomain
  },
  %{
    vector: :tcp_direct_ip,
    target: "1.1.1.1",
    port: 443,
    expect: :refused
  }
]
