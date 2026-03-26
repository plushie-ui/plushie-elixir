# Verify the plushie binary exists before running any tests.
# This is a hard requirement -- all plushie tests need the binary.
# The resolved path is stored in application env so test modules
# can read it without re-resolving.
binary = Plushie.Binary.path!()
Application.put_env(:plushie, :test_binary_path, binary)

test_backend =
  case System.get_env("PLUSHIE_TEST_BACKEND") do
    "headless" -> :headless
    "windowed" -> :windowed
    _ -> :mock
  end

# Start the shared session pool for test sessions.
{:ok, _} =
  Plushie.Test.SessionPool.start_link(
    name: Plushie.TestPool,
    renderer: binary,
    mode: test_backend,
    max_sessions: max(System.schedulers_online() * 8, 128)
  )

ExUnit.start()
