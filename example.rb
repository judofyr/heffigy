$: << 'lib'
require 'rubygems'
require 'heffigy'
require 'nokogiri'

class MyFilter < Heffigy::Filter
  def on_html(tag, scope, var)
    tag.inner do |content|
      [:if, var, [:dynamic, var], content]
    end
  end
end

template = <<-HTML
<div class="comment">
  <strong>Author:</strong>
  <p>Comment</p>
</div>
HTML

doc = Heffigy::Document.new(Nokogiri(template), :filter => MyFilter)

scope = doc.find('.comment p')
id = scope.log(:html)

values = []
values[id] = 'This is a <strong>lovely</strong> README'

puts doc.compiled_method
puts doc.render(*values)


