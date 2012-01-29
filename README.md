Heffigy - fast DOM manipulation template framework
==================================================

A DOM manipulation template consists of two parts. A template and a set
of transformations:

```html
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
    <p id="no-comments">There aren't any comments for this post.</p>
  </body>
</html>
```

```ruby
class PostView < Effigy::View
  attr_reader :post

  def initialize(post)
    @post = post
  end

  def transform
    text('h1', post.title)
    text('title', "#{post.title} - Site title")
    text('p.body', post.body)
    replace_each('.comment', post.comments) do |comment|
      text('h2', comment.title)
      text('p', comment.summary)
      attr('a', :href => url_for(comment))
    end
    remove('#no-comments') unless post.comments.empty?
  end
end
```

## The Naive Approach

There's very obvious and naive way to implement such a template engine:
Parse the template into a DOM and work directly with the tree.

```ruby
class Effigy::View
  def text(selector, value)
    find(selector).text = value
  end
end
```

This has two big disadvantages:

Performance. Because you're going to manipulate the tree, you'll need
to copy (or re-parse) and serialize it for every rendering. You're also
doing a lot of uneccesary selector queries (e.g. the H1-tag is in the
same location every time, but the library is going to query for it all
the time anyway).

Vague distinction between data and template. This is best demostrated
with an example:

```ruby
template = <<-HTML
  <div class="comment">
    <strong>Author:</strong>
    <p>Comment</p>
  </div>
HTML

def transform
  html('.comment p', 'This is a <strong>lovely</strong> README')
  text('.comment strong', 'Magnus Holm:')
end
```

Because there's no distinction between data *inserted* to the tree and
nodes *already present*, this will have the unfortunately consequence
of turning my comment into "This is a <strong>Magnus Holm:</strong>
README".

## The Performant Approach

As in all other (template) languages, there's a very simple thought
for improving performance: Figure out what needs to be done *once* and
what needs to be done *for every rendering*. Do as much as possible at
parse/compile-time and as little as possible at run/render-time.

In our case we see that the *querying* is something that only needs to be
done once, while the data gathering has to happen at render time.

```ruby
def transform
  text('h1', post.title)
  text('title', "#{post.title} - Site title")
  text('p.body', post.body)
  replace_each('.comment', post.comments) do |comment|
    text('h2', comment.title)
    text('p', comment.summary)
    attr('a', :href => url_for(comment))
  end
  remove('#no-comments') unless post.comments.empty?
end
```

More specifically, we want to evaluate this code once, logging the
location to the nodes the changes that were made on them. From this data
we can compile the template into optmized plain Ruby code (almost like
ERB).

```ruby
def render(h1, title, body, comments, empty)
  _buf = []
  _buf << "<html>
    <head>
      <title>#{title}</title>
    </head>
    <body>
      <h1>#{h1}</h1>
      <p class=\"body\">#{body}</p>"

  comments.each do |t, s, u|
    _buf << "<div class=\"comment\">
          <h2>#{t}</h2>
          <p>#{s}</p>
          <a#{" href=\"#{u}\"" if u}>View more</a>
        </div>"
  end

  if empty
    _buf << "<p id=\"no-comments\">There aren't any comments for this post.</p>"
  end

  _buf << "</body>
  </html>"
  _buf.join
end
```

It turns out that it's impossible to get this code after the first
rendering. The transformation behaves differently depending on how many
comments there are. If there were no comments, we wouldn't know how to
add the comment title and summary (the replace_each-block hasn't been
called), nor that the "no comments"-tag might be removed.

Therefore it's important to be able to recompile the template when we
have more knowledge. The moment the replace_each-block gets called,
we know that our compiled version doesn't handle it and we'll have
to compile a new version. In many ways, you could say this is a
Just-In-Time compiler.

## How Heffigy Solves It

Heffigy is a framework for implementing DOM manipulation template
engines. This means you'll have to write all the operations yourself,
but it gives you tools to simplify and speed up this process.

Let's implement `html` (replacing inner HTML):

```ruby
require 'heffigy'
require 'nokogiri'

template = <<-HTML
  <div class="comment">
    <strong>Author:</strong>
    <p>Comment</p>
  </div>
HTML

@doc = Heffigy::Document.new(Nokogiri(template))
```

A Document in Heffigy represents a template, and should only have one
document per template. This is typically something that would be a class
(instance) variable. From one document we can render the template:

```ruby
puts @doc.render
```

The general concept in Heffigy is that you use `#find` to zoom into a
scope, and that you can log certain properties on that scope. When you
log a property, you'll get back an ID. This ID represents the index of
the argument you'll have to pass to `#render`.

```ruby
def render_comment(comment)
  scope = @doc.find('.comment p')
  id = scope.log(:html)

  values = []
  values[id] = comment
  
  @doc.render(*values)
end

puts render_comment('This is a <strong>lovely</strong> README')
```

Both `#find` and `#log` are cached, so the first time they will do a
selector query and whatnot, but after that they're super fast.

However, it's not enough to just log properties, you must also tell
Heffigy what the properties means. Right now, our method will just
Houtput the exactly same template as before (because it doesn't know how
Hto handle `html` properties.

```ruby
class MyFilter < Heffigy::Filter
  def on_html(tag, scope, var)
    tag.inner do |content|
      [:if, var, [:dynamic, var], content]
    end
  end
end
```

All property events will be called with the tag, the scope and the
variable where the data is stored. The tag objects allows us to
manipulate the node in several ways. Here we define define an *inner
wrapper* which wraps around the inner content in the tag.

Each node in the tree can have several possible properties, and even if
some of those properties are not used in all renderings (we could have
`text('.comment p', 'foo') if something?`), we'll have to take care of
all of them at render time.

To see the compiled Ruby code, we need to tell Heffigy to use our filter.

```ruby
@doc = Heffigy::Document.new(Nokogiri(template), :filter => MyFilter)
# ... the other code ...

puts render_comment('This is a <strong>lovely</strong> README')
puts @doc.compiled_method

# here's what it says:
def compiled_render(_c0_0 = nil)
  _buf = []
  _buf << "<div class='comment'>\n    <strong>Author:</strong>\n    <p>"
  if _c0_0
    _buf << _c0_0
  else
    _buf << "Comment"
  end
  _buf << "</p>\n  </div>"
  _buf = _buf.join
end
```

### Log with Arguments

Sometimes it's not enough to specify a property name, you also want to
pass arguments. This simply works the way you expect.

```ruby
id = doc.find('.comment strong').log(:attr, :class)
values[id] = 'author'

class MyFilter
  def on_attr(tag, scope, var, name)
    tag.data[:attrs] ||= {}
    tag.data[:attrs][name] = var
  end
  
  # NOTE: This doesn't handle many important edge cases, but is simple
  # enough to understand the concept
  def compile_attributes(tag)
    exp = [:html, :attrs]

    # Compile stuff that's in variables
    (tag.data[:attrs] || {}).each do |name, var|
      exp << [:html, :attr, name, [:dynamic, var]]
    end

    # Compile stuff that's in the template
    tag.node.attributes.each do |name, value|
      exp << [:html, attr, name, [:static, value]]
    end
    
    exp
  end
end
```

Calling `doc.find('.comment strong').log(:attr, :class)` many times
will always return the same ID, while e.g. `doc.find('.comment
strong').log(:attr, :id)` returns a different ID.

### Arguments or Data

Let's say you want to have a `add_class` property. There's (at least)
two ways to solve that.

We can either pass the class as an argument:

```ruby
id = @doc.find('.comment strong').log(:add_class, 'hello')
values[id] = true

def on_add_class(tag, scope, var, klass)
  tag.data[:classes] ||= []
  tag.data[:classes] << [klass, var]
end

def compile_attributes(tag)
  # ...

  klass = [:multi]
  tag.data[:classes].each do |(klass, var)|
    klass << [:if, var, [:static, " #{klass}"]]
  end
  exp << [:html, :attr, 'class', klass]

  # ...
end
```

Or as data:

```ruby
id = @doc.find('.comment strong').log(:add_class)
values[id] ||= []
values[id] << 'hello'

def on_add_class(tag, scope, var, klass)
  tag.data[:classes] = var
end

def compile_attributes(tag)
  # ...
  
  klass = [:dynamic, tag.data[:classes].map { |x| " #{x}" } }.join ', ']
  exp << [:html, :attr, 'class', klass]
  
  # ...
end

```

The general rule is that passing arguments leads to faster rendering
*if* there's few distinct variations. Every distinct argument triggers
recompiling and generates separate code. If someone used the former
implementation and used `add_class '.comment', "comment_#{comment.id}"`,
the generated code would explode in size because it tries to handle all
the cases statically.

```ruby
_buf << "<div class=\"comment#{" comment_1" if _c0_0}#{" comment_2" if c0_1}#{" comment_3" if c0_2}\">
```

### Separate Contexts

By default, all the data will be passed as arguments directly to
`#render`. This works fine until we need loops. Heffigy allows you to
use separate *contexts* to deal with this problem.

```ruby
scope = @doc.find('.comment')

# create a new context for this scope
ctx = scope.in_context

result = []

%w|Hello There Man|.each do |comment|
  values = []
  id = ctx.find('p').log(:text)
  values[id] = comment
  result << values
end

p result
# [["Hello"], ["There"], ["Man"]]

id = scope.log(:replace_each)
values[id] = result

def on_replace_each(tag, scope, var)
  tag.outer do |ele|
    vars = scope.in_context.block_params
    [:block, "(#{var} || [[]]).each do |#{vars}|", ele]
  end
end

```

