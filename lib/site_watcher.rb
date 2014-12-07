require "site_watcher/version"

require "capybara"
require "rspec/expectations"
require "open-uri"
require "json"
require "logger"

class SiteWatcher
  def self.watch(opts={}, &block)
    trap(:SIGINT) { abort(?\n) }

    delay = opts.fetch(:every, 5)
    dsl = DSL::Top.new
    dsl.instance_eval(&block)

    new(dsl.pages).watch(delay)
  end

  def initialize(pages)
    @pages = pages
    @logger = ::Logger.new($stderr)
  end

  def watch(delay)
    @pages.cycle do |page|
      begin
        page.__run!
        @pages.delete(page)
      rescue ::RSpec::Expectations::ExpectationNotMetError
      rescue => e
        @logger.warn("Exception on #{page.url}: #{e.inspect}")
      end

      sleep(delay) if @pages.last == page
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
      include ::RSpec::Matchers
      attr_reader :url

      def initialize(url)
        @url = url
        @tests = []
      end

      def test(&block)
        @tests << block
      end

      def fulfilled(&block)
        @fulfilled = block
      end

      def __run!
        open(@url) do |response|
          case response.content_type
          when /json/i
            page = ::JSON.parse(response.read)
          else
            page = ::Capybara::Node::Simple.new(response.read)
          end

          @tests.each { |test| test.call(page) }
          @fulfilled.call(@url) if @fulfilled.respond_to?(:call)
        end
      end
    end
  end
end
