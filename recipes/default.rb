#
# Cookbook Name:: mozilla-sync
# Recipe:: default
#
# Copyright 2014, computerlyrik, Christian Fischer
#
# All rights reserved - Do Not Redistribute
#
require 'chef/shell_out'

package 'python-dev'
package 'make'
include_recipe 'git' # package 'git-core'
package 'python-virtualenv'

git node['mozilla-sync']['target_dir'] do
  repository node['mozilla-sync']['repository']
  action :checkout
  notifies :run, 'bash[build_source]', :immediately
end

bash 'build_source' do
  code 'make build'
  cwd node['mozilla-sync']['target_dir']
  action :nothing
  notifies :run, 'bash[install_gunicorn]', :immediately
end

bash 'install_gunicorn' do
  code './local/bin/easy_install gunicorn'
  cwd node['mozilla-sync']['target_dir']
  action :nothing
end

ruby_block 'create_random' do
  begin
    cmd = Mixlib::ShellOut.new('head -c 20 /dev/urandom | sha1sum  | rev | cut -c 4- | rev')
    cmd.run_command
    node.set_unless['mozilla-sync']['auth_secret'] = cmd.stdout
  end
  only_if { node['mozilla-sync']['auth_secret'].nil? }
end

template "#{node['mozilla-sync']['target_dir']}/syncserver.ini" do
  variables(
      public_url: "https://#{node['fqdn']}",
      secret: node['mozilla-sync']['auth_secret']
  )
  notifies :reload, 'service[sync]', :delayed
end

cmd = "#{node['mozilla-sync']['target_dir']}/local/bin/pserve #{node['mozilla-sync']['target_dir']}/syncserver.ini"
start_cmd = "#{cmd} --daemon --log-file=#{node['mozilla-sync']['logfile']}"
stop_cmd = "#{cmd} --stop-daemon"

service 'sync' do
  start_command start_cmd
  stop_command stop_cmd
  reload_command "#{cmd} --reload"
  restart_command "#{stop_cmd} || true && #{start_cmd}"
  supports start: true, stop: true, reload: true
  action :start
end

include_recipe 'nginx'

certificate_manage 'mozilla-sync' do
  search_id node['mozilla-sync']['certificate_databag_id']
  cert_path '/etc/nginx/ssl'
  nginx_cert true
  not_if { node['mozilla-sync']['certificate_databag_id'].nil? }
end

template '/etc/nginx/sites-available/syncserver' do
  owner 'root'
  group 'root'
  mode '0644'
  source 'nginx.syncserver.erb'
  notifies :restart, 'service[nginx]'
  variables(
      server_name: node['fqdn'],
      ssl_certificate: node['mozilla-sync']['ssl_certificate'],
      ssl_certificate_key: node['mozilla-sync']['ssl_certificate_key']
  )
end

nginx_site 'syncserver' do
  enable true
end

# Disable default site
nginx_site 'default' do
  enable false
end
