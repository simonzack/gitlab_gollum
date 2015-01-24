#!/usr/bin/env ruby
require 'open-uri'
require 'nokogiri'
require 'gollum/app'


class NotFound
  F = ::File

  def initialize(app, path)
    @app = app
    file = F.expand_path(path)
    @content = F.read(file)
    @length = @content.size.to_s
  end

  def call(env)
    res = @app.call(env)
    if res.nil?
        [404, {'Content-Type' => 'text/html', 'Content-Length' => @length}, [@content]]
    else
        res
    end
  end
end


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
        status, headers, response = Precious::App.call(env)
        if headers.fetch('Content-Type', '').start_with?('text/html')
            # re-write response
            options = Hash[env
                .select {|k,v| k.start_with? 'HTTP_'}
                .map {|k,v| [k.sub(/^HTTP_/, ''), v]}
            ]
            options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
            doc = Nokogiri::HTML(open(env['rack.url_scheme'] + '://' + request.host + project_path, options))
            wiki_doc = Nokogiri::HTML(response[0])
            doc.css('head')[0].inner_html += wiki_doc.css('head')[0].inner_html
            doc.css('.content')[0].inner_html = wiki_doc.css('body')[0].inner_html
            response_str = doc.to_s
            headers['Content-Length'] = response_str.size.to_s
            response = [response_str]
        end
        [status, headers, response]
    end
  end
end


Precious::App.set(:default_markup, :markdown)
Precious::App.set(:wiki_options, {
    :universal_toc => false,
    :mathjax => true,
    :live_preview => true
})

use NotFound, 'public/404.html'
run GitlabGollum.new
