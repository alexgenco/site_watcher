require "site_watcher/version"
require "open-uri"
require "nokogiri"

class SiteWatcher
  def self.watch(opts={}, &block)
    trap(:SIGINT) { abort(?\n) }

    sleep_interval = opts.fetch(:sleep, 0)

    new([]).tap do |instance|
      DSL::Top.new(instance).instance_eval(&block)
    end.watch(sleep_interval)
  end

  attr_accessor :pages

  def initialize(pages)
    @pages = pages
  end

  def watch(sleep_interval)
    @pages.cycle do |page|
      if page.reset.fulfilled?
        @pages.delete(page)
      else
        sleep(sleep_interval)
      end
    end
  end

  module DSL
    class Top
      def initialize(watcher)
        @watcher = watcher
      end

      def page(url, &block)
        Page.new(url).tap do |page|
          page.instance_eval(&block)
          @watcher.pages << page
        end
      end
    end

    class Page
      attr_reader :url

      def initialize(url)
        @url = url
        @tests = []
      end

      def reset
        @document = nil
        self
      end

      def document
        @document ||= Nokogiri::HTML(open(@url))
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
        instance_eval(&block)
      end

      def fulfilled?
        @css.all?(&:fulfilled?)
      end

      def css
        CSS.new(@page.document).tap do |css|
          @css << css
        end
      end
    end

    class CSS
      def initialize(document)
        @document = document
        @exclusions = []
        @inclusions = []
      end

      def fulfilled?
        @inclusions.all? do |css|
          @document.at_css(css)
        end && @exclusions.all? do |css|
          !@document.at_css(css)
        end
      end

      def excludes(str)
        @exclusions << str
      end

      def includes(str)
        @inclusions << str
      end
    end
  end
end
