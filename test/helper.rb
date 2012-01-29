require 'rubygems'
require 'minitest/autorun'
require 'heffigy'

class TestHeffigy < MiniTest::Unit::TestCase
  def pretty(html)
    ugly = Nokogiri::HTML(html, &:noblanks)
    ugly.traverse do |x|
      x.content = x.content.strip if x.text?
    end
    ugly.to_xhtml
  end

  def assert_html(exp, act)
    assert_equal pretty(exp), pretty(act)
  end
end

