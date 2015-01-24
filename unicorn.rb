worker_processes 1
listen "/tmp/gitlab_gollum.socket", :backlog => 1024
timeout 60
pid "/tmp/unicorn.pid"
preload_app true
