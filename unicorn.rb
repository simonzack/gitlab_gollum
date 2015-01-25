worker_processes 1
listen "/run/gitlab-gollum/gitlab-gollum.socket", :backlog => 1024
timeout 60
pid "/run/gitlab-gollum/unicorn.pid"
preload_app true
