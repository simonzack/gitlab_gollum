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


class InternalError
  F = ::File

  def initialize(app, path)
    @app = app
    file = F.expand_path(path)
    @content = F.read(file)
    @length = @content.size.to_s
  end

  def call(env)
    res = @app.call(env)
  rescue StandardError, LoadError, SyntaxError => e
    [500, {'Content-Type' => 'text/html', 'Content-Length' => @length}, [@content]]
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
    project_path = request.path.split('/')[0..2].join('/')
    base_path = project_path + '/wikis'
    repo_path = '/var/lib/gitlab/repositories' + project_path + '.wiki.git'
    if File.directory?(repo_path)
      if request.path.split('/')[4] == 'gollum'
        base_path += '/gollum'
        request_path = request.path
        env['SCRIPT_NAME'] = base_path
        env['PATH_INFO'] = request_path[base_path.length..-1]
        Precious::App.set(:gollum_path, repo_path)
        Precious::App.set(:base_path, base_path)
        Precious::App.call(env)
      else
        gollum_path = base_path + '/gollum' + request.path[base_path.length..-1]
        options = Hash[env
          .select {|k,v| k.start_with? 'HTTP_'}
          .map {|k,v| [k.sub(/^HTTP_/, ''), v]}
        ]
        options[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
        doc = Nokogiri::HTML(open(env['rack.url_scheme'] + '://' + request.host + project_path, options))
        script = Nokogiri::XML::Node.new 'script', doc
        script.inner_html = '
          function updateIframe(contentWindow){
            parts = contentWindow.location.pathname.split("/");
            parts.splice(4, 1);
            window.history.replaceState({} , contentWindow.title, parts.join("/"));
          }
        '
        doc.at_css('header') << script
        style = Nokogiri::XML::Node.new 'style', doc
        style.inner_html = '
          html, body, .page-with-sidebar, .content-wrapper, iframe {width: 100%; height: 100%;}
          html, body {overflow: hidden;}
          .content-wrapper {padding: 0px;}
        '
        doc.at_css('header') << style
        doc.at_css('.content-wrapper').inner_html =
          "<iframe src=\"#{gollum_path}\" frameborder=\"0\" onload=\"updateIframe(this.contentWindow)\"></iframe>"
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
use InternalError, 'public/500.html'
run GitlabGollum.new
