

# time is an issue here.  I'd of loved to use the nginx cookbook, or at least
# setup my own server block.  To get to the other parts of the project, 
# going with a very minimal solution here.

package 'nginx'

service 'nginx' do
  supports  restart: true, start: true, stop: true, reload: true, status: true
  action    [ :start, :enable ]
end

cookbook_file node[:welcome_page][:nginx][:index_html] do
  source    'index.html'
  owner     'root'
  group     'root'
  mode      '0644'
  action    :create
end
