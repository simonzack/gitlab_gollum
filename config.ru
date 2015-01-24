#!/usr/bin/env ruby
require 'gollum/app'

class GitlabGollum
  def call(env)
    request = Rack::Request.new(env)
    project_path = '/' + request.path.split('/', 4)[1..2].join('/')
    base_path = project_path + '/wikis'
    gollum_path = '/var/lib/gitlab/repositories' + project_path + '.wiki.git'
    if File.directory?(gollum_path)
        env['SCRIPT_NAME'] = env['PATH_INFO'][0..base_path.length-1]
        env['PATH_INFO'] = env['PATH_INFO'][base_path.length..-1]
        Precious::App.set(:gollum_path, gollum_path)
        Precious::App.set(:base_path, base_path)
        return Precious::App.call(env)
    end
    [404, {'Content-Type' => 'text/html' }, ['Wiki doesn\'t exist']]
  end
end

Precious::App.set(:default_markup, :markdown)
Precious::App.set(:wiki_options, {
    :universal_toc => false,
    :mathjax => true,
    :live_preview => true
})

run GitlabGollum.new
