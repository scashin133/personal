set :application, "personal"
set :repository,  "git clone git@github.com:scashin133/personal.git"

server "shawnisadick.com", :app, :web, :db, :primary => true

set :user, "shawnis"

set :scm, :git
set :scm_username, "scashin133"
set :scm_passphrase, "Your@m0m"
set :runner, "scashin133"
set :use_sudo, false
set :branch, "master"
set :deploy_via, :remote_cache
set :git_shallow_clone, 1
set :deploy_to, "/home/shawnis/apps/personal"
default_run_options[:pty] = true