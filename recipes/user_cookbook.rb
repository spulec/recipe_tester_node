user = node['username']
data_bag = data_bag_item('recipe-tester', 'config')

cookbook_name = data_bag['cookbook_name']
cookbook_url = data_bag['cookbook_url']

git "Clone #{cookbook_name}" do
  user user
  group user
  repository cookbook_url
  reference "master"
  destination "/var/chef/cookbooks/#{cookbook_name}"
  action :checkout
  notifies :run, "execute[s3cmd install]"
end

template "/var/chef/run_list.json" do
  source "run_list.erb"
  owner user
  group user
  variables(
    :run_list => data_bag['run_list'])
  notifies :run, "execute[Run chef-solo]"
end

execute "Run chef-solo" do
  command "chef-solo -j /var/chef/run_list.json"
  action :nothing
  notifies :run, "execute[shutdown]"
end

execute "shutdown" do
  command "echo 'sudo shutdown -h now'"
  action :nothing
end
