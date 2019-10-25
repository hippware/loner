# LocalCluster-specific test setup
:ok = LocalCluster.start()
Application.ensure_all_started(:loner)

ExUnit.start()
