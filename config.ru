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
  def add_class(node, name)
    node['class'] = (node['class'].split(' ') | [name]).join(' ')
  end

  def remove_class(node, name)
    node['class'] = (node['class'].split(' ') - [name]).join(' ')
  end

  def call(env)
    request = Rack::Request.new(env)
    project_path = '/' + request.path.split('/')[1..2].join('/')
    base_path = project_path + '/wikis/gollum'
    gollum_path = '/var/lib/gitlab/repositories' + project_path + '.wiki.git'
    if File.directory?(gollum_path)
      if request.path.split('/')[4] == 'gollum'
        env['SCRIPT_NAME'] = env['PATH_INFO'][0..base_path.length-1]
        env['PATH_INFO'] = env['PATH_INFO'][base_path.length..-1]
        Precious::App.set(:gollum_path, gollum_path)
        Precious::App.set(:base_path, base_path)
        Precious::App.call(env)
      else
        options = Hash[env
          .select {|k,v| k.start_with? 'HTTP_'}
          .map {|k,v| [k.sub(/^HTTP_/, ''), v]}
        ]
        options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
        doc = Nokogiri::HTML(open(env['rack.url_scheme'] + '://' + request.host + project_path, options))
        style = Nokogiri::XML::Node.new 'style', doc
        style.inner_html = '
          html, body, .page-with-sidebar, .content-wrapper, iframe {width: 100%; height: 100%;}
          html, body {overflow: hidden;}
          .content-wrapper {padding: 0px;}
        '
        doc.at_css('header') << style
        doc.at_css('.content-wrapper').inner_html = "<iframe src=\"#{base_path}\" frameborder=\"0\"></iframe>"
        remove_class(doc.at_css('.shortcuts-project').parent, 'active')
        add_class(doc.at_css('.shortcuts-wiki').parent, 'active')
        response_str = doc.to_s
        [200, {
          'Content-Type' => 'text/html;charset=utf-8',
          'Content-Length' => (response_str.size + 2).to_s
        }, [response_str]]
      end
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
