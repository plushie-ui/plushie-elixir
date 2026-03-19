# Load extension packages' compiled beam files so coexistence tests work.
# These are path deps of toddy, but we can't add them as Mix deps because
# they depend on :toddy (circular). Instead, we load their compiled beam
# files directly. Each extension must be compiled in its own directory first.
for ext <- ~w(toddy_sparkline toddy_hex_view toddy_code_view toddy_plot toddy_timeline) do
  ebin = Path.expand("../../#{ext}/_build/dev/lib/#{ext}/ebin", __DIR__)

  if File.dir?(ebin) do
    Code.append_path(ebin)
  end
end

# Start the shared session pool for pooled test backends.
{:ok, _} =
  Toddy.Test.SessionPool.start_link(
    name: Toddy.TestPool,
    mode: :mock,
    max_sessions: System.schedulers_online() * 2
  )

ExUnit.start()
