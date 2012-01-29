require 'helper'
require 'heffigy/view'

class TestHeffigyView < TestHeffigy
  class Simple < Heffigy::View
    template <<-HTML
      <html>
        <head>
          <title></title>
        </head>
        <body>
          <h1></h1>
          <p class="body"></p>
          <div class="comment">
            <h2></h2>
            <p></p>
            <a>View more</a>
          </div>
        </body>
      </html>
    HTML
  end


  def test_just_render
    s = Simple.new
    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title></title>
        </head>
        <body>
          <h1></h1>
          <p class="body"></p>
          <div class="comment">
            <h2></h2>
            <p></p>
            <a>View more</a>
          </div>
        </body>
      </html>
    HTML
  end

  def test_html
    def (s = Simple.new).transform
      text 'title, .body', 'Hello World'
    end

    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title>Hello World</title>
        </head>
        <body>
          <h1></h1>
          <p class="body">Hello World</p>
          <div class="comment">
            <h2></h2>
            <p></p>
            <a>View more</a>
          </div>
        </body>
      </html>
    HTML
  end

  def test_find
    def (s = Simple.new).transform
      find('title').text 'Hello World'
      find('.comment h2').text 'Nice'
    end

    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title>Hello World</title>
        </head>
        <body>
          <h1></h1>
          <p class="body"></p>
          <div class="comment">
            <h2>Nice</h2>
            <p></p>
            <a>View more</a>
          </div>
        </body>
      </html>
    HTML
  end

  class Comment < Struct.new(:id, :title, :summary)
  end

  Comments = [
    Comment.new(1, 'Hello', 'First comment'),
    Comment.new(2, 'World', 'Second comment')
  ]

  def test_replace_each
    def (s = Simple.new).transform
      text 'title', 'Hello World'
      replace_each '.comment', Comments do |comment|
        text 'h2', comment.title
        text 'p', comment.summary
        attr 'a', :href => "/c/#{comment.id}"
      end
    end

    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title>Hello World</title>
        </head>
        <body>
          <h1></h1>
          <p class="body"></p>
          <div class="comment">
            <h2>Hello</h2>
            <p>First comment</p>
            <a href='/c/1'>View more</a>
          </div>
          <div class="comment">
            <h2>World</h2>
            <p>Second comment</p>
            <a href='/c/2'>View more</a>
          </div>
        </body>
      </html>
    HTML
  end

  def test_replace_each_title
    def (s = Simple.new).transform
      replace_each '.comment', Comments do |comment|
        text 'h2', comment.title
      end
    end
    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title></title>
        </head>
        <body>
          <h1></h1>
          <p class="body"></p>
          <div class="comment">
            <h2>Hello</h2>
            <p></p>
            <a>View more</a>
          </div>
          <div class="comment">
            <h2>World</h2>
            <p></p>
            <a>View more</a>
          </div>
        </body>
      </html>
    HTML
  end

  def test_attr_replace
    def (s = Simple.new).transform
      attr '.body', :class => 'head'
    end

    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title></title>
        </head>
        <body>
          <h1></h1>
          <p class="head"></p>
          <div class="comment">
            <h2></h2>
            <p></p>
            <a>View more</a>
          </div>
        </body>
      </html>
    HTML
  end

  def test_remove
    def (s = Simple.new).transform
      remove '.comment'
    end

    str = s.render
    assert_html str, <<-HTML
      <html>
        <head>
          <title></title>
        </head>
        <body>
          <h1></h1>
          <p class="body"></p>
        </body>
      </html>
    HTML
  end
end

