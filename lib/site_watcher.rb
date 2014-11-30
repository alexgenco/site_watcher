require "site_watcher/version"
require "open-uri"
require "nokogiri"

class SiteWatcher
  class CSSTest
    def initialize(html)
      @html = html
      @pass = true
    end

    def pass?
      !!@pass
    end

    def includes(css)
      @pass = !@html.at_css(css).nil?
    end
  end

  class Page
    def initialize(content)
      @html = Nokogiri::HTML(content)
      @tests = []
    end

    def css
      CSSTest.new(@html).tap do |css|
        @tests << css
      end
    end

    def tests_pass?
      @tests.all?(&:pass?)
    end
  end

  class Result
    def success(&block)
      return @success unless block_given?
      @success = block
    end

    def failure(&block)
      return @failure unless block_given?
      @failure = block
    end
  end

  def initialize(url)
    raise(ArgumentError, "block required") unless block_given?

    @url = url
    @page = Page.new(open(url))
    yield @page
  end

  def watch(&block)
    raise(ArgumentError, "block required") unless block_given?
    yield result = Result.new

    if @page.tests_pass?
      result.success.call(@url)
    else
      result.failure.call(@url)
    end
  end
end
