user = node['username']
data_bag = data_bag_item('recipe-tester', 'config')

['rubygems', 'vim', 'git'].each do |pkg|
    package pkg do
        :install
    end
end

template "/home/ubuntu/.s3cfg" do
  source "s3cfg.erb"
  owner user
  group user
  variables(
    :session_token => data_bag['s3_session_token'],
    :access_key => data_bag['s3_access_key'],
    :secret_key => data_bag['s3_secret_key'])
end

git "Clone s3cmd" do
  user user
  group user
  repository "https://github.com/s3tools/s3cmd.git"
  reference "448d5d0f4f98a9a70cef39ac98de931f9d4961bd"
  destination "/var/s3cmd"
  action :checkout
  notifies :run, "execute[s3cmd install]"
end

execute "s3cmd install" do
  command "cd /var/s3cmd && sudo python setup.py install"
  action :nothing
end

directory "/var/chef/cookbooks" do
  owner user
  group user
end
