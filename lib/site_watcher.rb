require "site_watcher/version"
require "open-uri"
require "nokogiri"

class SiteWatcher
  class CSSTest
    def initialize(html)
      @html = html
      @results = []
    end

    def pass?
      @results.all?
    end

    def includes(css)
      @results << !!@html.at_css(css)
      self
    end

    def excludes(css)
      @results << !@html.at_css(css)
      self
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

  def initialize(url, &test_handler)
    raise(ArgumentError, "block required") unless block_given?

    @url = url
    @test_handler = test_handler
  end

  def watch(&result_handler)
    raise(ArgumentError, "block required") unless block_given?

    page = Page.new(open(@url))
    @test_handler.call(page)

    result = Result.new
    result_handler.call(result)

    if page.tests_pass?
      result.success.call(@url)
    else
      result.failure.call(@url)
    end
  end
end
