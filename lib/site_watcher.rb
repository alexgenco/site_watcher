require "site_watcher/version"
require "open-uri"
require "nokogiri"
require "json"

class SiteWatcher
  def self.watch(opts={}, &block)
    trap(:SIGINT) { abort(?\n) }

    sleep_interval = opts.fetch(:sleep, 5)

    dsl = DSL::Top.new
    dsl.instance_eval(&block)
    new(dsl.pages).watch(sleep_interval)
  end

  def initialize(pages)
    @pages = pages
  end

  def watch(sleep_interval)
    @pages.cycle do |page|
      @pages.delete(page) if page.fulfilled?
      sleep(sleep_interval)
    end
  end

  module DSL
    class Top
      attr_reader :pages

      def initialize
        @pages = []
      end

      def page(url, &block)
        Page.new(url).tap do |page|
          page.instance_eval(&block)
          @pages << page
        end
      end
    end

    class Page
      attr_reader :url

      def initialize(url)
        @url = url
        @tests = []
      end

      def fulfilled?
        tests = @tests.map { |prc| Test.new(self, &prc) }

        if tests.all?(&:fulfilled?)
          @fulfilled.call if @fulfilled.respond_to?(:call)
          true
        else
          false
        end
      end

      def test(&block)
        @tests << block
      end

      def fulfilled(&block)
        @fulfilled = block
      end
    end

    class Test
      def initialize(page, &block)
        @page = page
        @css = []
        @json = []
        instance_eval(&block)
      end

      def fulfilled?
        @css.all?(&:fulfilled?) &&
          @json.all?(&:fulfilled?)
      end

      def css
        CSS.new(@page.url).tap do |css|
          @css << css
        end
      end

      def json
        JSON.new(@page.url).tap do |json|
          @json << json
        end
      end
    end

    class CSS
      def initialize(url)
        @url = url
        @exclusions = []
        @inclusions = []
      end

      def fulfilled?
        @document = nil
        @inclusions.all? do |css|
          document.at_css(css)
        end && @exclusions.all? do |css|
          !document.at_css(css)
        end
      end

      def document
        @document ||= Nokogiri::HTML(open(@url))
      end

      def excludes(str)
        @exclusions << str
        self
      end

      def includes(str)
        @inclusions << str
        self
      end
    end

    class JSON
      class Test
        def initialize(url, path)
          @path = path
          @url = url
          @includes = []
          @excludes = []
        end

        def fulfilled?
          @content = nil

          @includes.all? do |incl|
            case incl
            when String
              content.include?(incl)
            when Regexp
              content =~ incl
            end
          end && @excludes.all? do |excl|
            case excl
            when String
              !content.include?(excl)
            when Regexp
              content !~ excl
            end
          end
        end

        def content
          @content ||= begin
            json = ::JSON.load(open(@url))
            @path.inject(json, :fetch)
          end
        end

        def excludes(str_or_regex)
          @excludes << str_or_regex
          self
        end

        def includes(str_or_regex)
          @includes << str_or_regex
          self
        end
      end

      def initialize(url)
        @url = url
        @tests = []
      end

      def fulfilled?
        @tests.all?(&:fulfilled?)
      end

      def at(*path)
        Test.new(@url, path).tap do |test|
          @tests << test
        end
      end
    end
  end
end
