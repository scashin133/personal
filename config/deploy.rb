require 'socialcast/recipes/mongrel_cluster'

set :application, "personal"
set :repository,  "git@github.com:scashin133/personal.git"

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

set :mongrel_servers, 1
set :mongrel_port, 4118
set :mongrel_address, "127.0.0.1"
set :mongrel_environment, "production"
set :mongrel_conf, "/home/shawnis/etc/mongrel_conf.yml"
set :project_current_path, "/home/shawnis/apps/personal"

after "deploy:update_code", "deploy:copy_config_files"

namespace :deploy do
  desc <<-DESC
  Copies configuration files for the current deployment from 1) config/deploy/config, and then 2) shared/config
  DESC

  task :copy_config_files, :roles => [:app] do

    # Next copy and overwrite any files specified in the shared/config folders
    run "cp -R #{shared_path}/config/* #{latest_release}/config/; true"
  end
  
end