#!/usr/bin/env ruby
require 'gollum/app'

class GitlabGollum
  def call(env)
    request = Rack::Request.new(env)
    name = request.path.split('/', 3)[1]
    if not name.nil?
        gollum_path = '../' + name
        if File.directory?(gollum_path)
            env['SCRIPT_NAME'] = env['PATH_INFO'][0..('/' + name).length-1]
            env['PATH_INFO'] = env['PATH_INFO'][('/' + name).length..-1]
            # puts env
            Precious::App.set(:gollum_path, gollum_path)
            Precious::App.set(:base_path, name)
            return Precious::App.call(env)
        end
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
