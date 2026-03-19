# Verify the toddy binary exists before running any tests.
# This is a hard requirement -- all toddy tests need the binary.
# The resolved path is stored in application env so test modules
# can read it without re-resolving.
binary = Toddy.Binary.path!()
Application.put_env(:toddy, :test_binary_path, binary)

# Start the shared session pool for pooled test backends.
{:ok, _} =
  Toddy.Test.SessionPool.start_link(
    name: Toddy.TestPool,
    renderer: binary,
    mode: :mock,
    max_sessions: max(System.schedulers_online() * 8, 128)
  )

ExUnit.start()
