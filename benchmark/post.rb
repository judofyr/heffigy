$:.unshift 'lib'
require 'rubygems'
require 'heffigy/view'
require 'effigy'
require 'pp'
require 'benchmark'
require 'erb'
require 'cgi'

module PostView
  def initialize(post)
    @post = post
  end

  def transform
    text('h1', @post.title)
    text('title', "#{@post.title} - Site title")
    html('.body', @post.body)
    remove('#no-comments') unless @post.comments.empty?
    replace_each('.comment', @post.comments) do |comment|
      append('h2', comment.title)
      html('div', comment.summary)
      attr('a', :href => "/comments/#{comment.id}")
    end
  end
end

class EffigyPV < Effigy::View
  include PostView

  def render_html(data)
    @current_context = Nokogiri::HTML(data)
    transform
    output
  end
end

class HeffigyPV < Heffigy::View
  file "post.html"
  include PostView
end

class ErbPV
  include PostView
  erb = ERB.new(File.read("post.erb"))
  erb.def_method(self, :render)
  
  def h(str)
    CGI.escapeHTML(str.to_s)
  end
end

## Data

class Post < Struct.new(:id, :title, :body, :comments)
end

class Comment < Struct.new(:id, :title, :summary)
end

cmt = Comment.new(1, "Hello <strong>nice</strong>", "Cool")
cmt2 = Comment.new(2, "Hello #2", "Cool")
post = Post.new(1, "Example Post #1", "Body", [cmt, cmt2])
post2 = Post.new(1, "Example Post #2", "Body", [])

N = 1000

data = File.read('post.html')

Benchmark.bmbm do |x|
  x.report("ERB") do
    N.times do
      ErbPV.new(post).render
      ErbPV.new(post2).render
    end
  end
  
  x.report("Heffigy") do
    N.times do
      HeffigyPV.new(post).render
      HeffigyPV.new(post2).render
    end
  end

  x.report("Effigy")  do
    N.times do
      EffigyPV.new(post).render_html(data)
      EffigyPV.new(post2).render_html(data)
    end
  end
end

