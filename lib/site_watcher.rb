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
    new(dsl.__sw_pages, delay, logger).watch
  end

  def initialize(pages, delay, logger)
    @pages = pages
    @delay = delay
    @logger = logger
    @force = false
  end

  def watch
    capture_signals do
      loop do
        break if @pages.empty?

        force = @force
        @force &&= false

        @pages.each do |page|
          begin
            page.__sw_run!(force)
            @pages.delete(page) if page.__sw_remove_on_fulfillment
          rescue ::RSpec::Expectations::ExpectationNotMetError
          rescue => e
            @logger.warn("Exception on #{page.__sw_url}: #{e.inspect}")
          end
        end

        sleep(@delay)
      end
    end
  end

  private

  def capture_signals
    ::Signal.trap(:INT) { abort(?\n) }

    ::Signal.trap(:USR1) do
      ::Thread.new do
        @logger.warn("Received USR1, next round of tests will force fulfillment")
      end.join

      @force = true
    end

    yield
  ensure
    ::Signal.trap(:INT, "DEFAULT")
    ::Signal.trap(:USR1, "DEFAULT")
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
      attr_reader :__sw_url, :__sw_remove_on_fulfillment

      def initialize(url)
        @__sw_url = url
        @__sw_tests = []
        @__sw_headers = {}
        @__sw_remove_on_fulfillment = true
      end

      def test(&block)
        @__sw_tests << block
      end

      def fulfilled(&block)
        @__sw_fulfilled = block
      end

      def headers(hash)
        @__sw_headers = hash
      end

      def remove_on_fulfillment(bool)
        @__sw_remove_on_fulfillment = !!bool
      end

      def __sw_run!(force=false)
        ::OpenURI.open_uri(@__sw_url, @__sw_headers) do |response|
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
