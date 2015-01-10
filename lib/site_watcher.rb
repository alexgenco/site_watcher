require "site_watcher/version"

require "capybara"
require "rspec/expectations"
require "open-uri"
require "json"
require "logger"

class SiteWatcher
  def self.watch(opts={}, &block)
    trap(:SIGINT) { abort(?\n) }

    dsl = DSL::Top.new
    dsl.instance_eval(&block)

    delay = opts.fetch(:every, 5)
    logger = opts.fetch(:logger, ::Logger.new($stderr))
    new(dsl.__sw_pages, logger).watch(delay)
  end

  def initialize(pages, logger)
    @pages = pages
    @logger = logger
    @force = false
  end

  def watch(delay)
    capture_signals do
      loop do
        break if @pages.empty?

        force = @force
        @force &&= false
        @logger.warn("Received USR1, forcing fulfillment of all tests") if force

        @pages.each do |page|
          begin
            page.__sw_run!(force)
            @pages.delete(page)
          rescue ::RSpec::Expectations::ExpectationNotMetError
          rescue => e
            @logger.warn("Exception on #{page.url}: #{e.inspect}")
          end
        end

        sleep(delay)
      end
    end
  end

  private

  def capture_signals
    ::Signal.trap(:USR1) { @force = true }
    ::Signal.trap(:INT)  { abort(?\n) }
    yield
  ensure
    ::Signal.trap(:USR1, "DEFAULT")
    ::Signal.trap(:INT, "DEFAULT")
  end

  module DSL
    class Top
      attr_reader :__sw_pages

      def initialize
        @__sw_pages = []
      end

      def page(url, &block)
        page = Page.new(url)
        page.instance_eval(&block)
        @__sw_pages << page
      end
    end

    class Page
      include ::RSpec::Matchers
      attr_reader :url

      def initialize(url)
        @__sw_url = url
        @__sw_tests = []
      end

      def test(&block)
        @__sw_tests << block
      end

      def fulfilled(&block)
        @__sw_fulfilled = block
      end

      def __sw_run!(force=false)
        ::OpenURI.open_uri(@__sw_url) do |response|
          case response.content_type
          when /json/i
            page = ::JSON.parse(response.read)
          else
            page = ::Capybara::Node::Simple.new(response.read)
          end

          begin
            @__sw_tests.each { |test| test.call(page) }
          rescue ::RSpec::Expectations::ExpectationNotMetError => err
            __sw_fulfilled! if force
            raise(err)
          end

          __sw_fulfilled!
        end
      end

      private

      def __sw_fulfilled!
        @__sw_fulfilled.call(@__sw_url) if @__sw_fulfilled.respond_to?(:call)
      end
    end
  end
end
