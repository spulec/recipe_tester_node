require 'net/http'

user = node['username']
data_bag = data_bag_item('recipe-tester', 'config')

cookbook_name = data_bag['cookbook_name']
cookbook_url = data_bag['cookbook_url']
commit_reference = data_bag['cookbook_commit']
build_id = data_bag['build_id']

git "Clone #{cookbook_name}" do
  user user
  group user
  repository cookbook_url
  reference commit_reference
  destination "/var/chef/cookbooks/#{cookbook_name}"
  action :checkout
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
  command "chef-solo -j /var/chef/run_list.json > /var/chef/user_cookbook.log; echo $? > /var/chef/user_output.txt"
  action :nothing
  ignore_failure true
  notifies :create, "ruby_block[post_results]"
end

ruby_block "post_results" do
  block do
    uri = URI.parse("http://recipe-tester.com/build/status")
    response = Net::HTTP.post_form(uri, {
      "build_id" => build_id,
      "secret_key" => data_bag['s3_secret_key'],
      "status" => File.read("/var/chef/user_output.txt")
    })
  end
  action :nothing
  notifies :run, "execute[shutdown]"
end

execute "shutdown" do
  command "sudo shutdown -h now"
  action :nothing
end
