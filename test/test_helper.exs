# Load extension packages' compiled beam files so coexistence tests work.
# These are path deps of julep, but we can't add them as Mix deps because
# they depend on :julep (circular). Instead, we load their compiled beam
# files directly. Each extension must be compiled in its own directory first.
for ext <- ~w(julep_sparkline julep_hex_view julep_code_view julep_plot julep_timeline) do
  ebin = Path.expand("../../#{ext}/_build/dev/lib/#{ext}/ebin", __DIR__)

  if File.dir?(ebin) do
    Code.append_path(ebin)
  end
end

ExUnit.start()
