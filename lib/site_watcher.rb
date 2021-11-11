require "site_watcher/version"

require "capybara"
require "http"
require "json"
require "logger"
require "rspec/expectations"

class SiteWatcher
  def self.watch(opts={}, &block)
    dsl = DSL::Top.new
    dsl.instance_eval(&block)

    delay = opts.fetch(:every, 5)
    logger = opts.fetch(:logger, ::Logger.new($stderr, level: :warn))
    timeout = opts.fetch(:timeout, {connect: 3, read: 10})

    new(
      dsl.__sw_before_hooks,
      dsl.__sw_pages,
      dsl.__sw_after_hooks,
      delay,
      logger,
      timeout,
    ).watch
  end

  def initialize(before_hooks, pages, after_hooks, delay, logger, timeout)
    @before_hooks = before_hooks
    @pages = pages
    @after_hooks = after_hooks
    @delay = delay
    @logger = logger
    @timeout = timeout
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
            page.__sw_run!(force, @logger, @timeout)
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

    @before_hooks.each(&:call)
    yield
  ensure
    ::Signal.trap(:INT, "DEFAULT")
    ::Signal.trap(:USR1, "DEFAULT")

    @after_hooks.each(&:call)
  end

  module DSL
    class Top
      attr_reader :__sw_pages, :__sw_before_hooks, :__sw_after_hooks

      def initialize
        @__sw_pages = []
        @__sw_before_hooks = []
        @__sw_after_hooks = []
      end

      def before(&block)
        @__sw_before_hooks << block
      end

      def after(&block)
        @__sw_after_hooks << block
      end

      def page(url, **opts, &block)
        page = Page.new(url, **opts)
        page.instance_eval(&block)
        @__sw_pages << page
      end
    end

    class Page
      include ::RSpec::Matchers
      attr_reader :__sw_url, :__sw_remove_on_fulfillment

      def initialize(url, method: :get, headers: {}, **opts)
        @__sw_url = url
        @__sw_tests = []
        @__sw_method = method
        @__sw_headers = headers
        @__sw_http_opts = opts
        @__sw_fulfilled = nil
        @__sw_fetch = nil
        @__sw_remove_on_fulfillment = true
      end

      def test(&block)
        @__sw_tests << block
      end

      def fulfilled(&block)
        @__sw_fulfilled = block
      end

      def fetch(&block)
        @__sw_fetch = block
      end

      def headers(hash)
        @__sw_headers = hash
      end

      def http_method(http_method)
        @__sw_http_method = http_method
      end

      def body(body)
        @__sw_body = body
      end

      def remove_on_fulfillment(bool)
        @__sw_remove_on_fulfillment = !!bool
      end

      def __sw_run!(force, logger, timeout)
        if @__sw_fetch
          response = @__sw_fetch.call(@__sw_url)
        else
          response = ::HTTP
            .use(logging: {logger: logger})
            .timeout(timeout)
            .headers(@__sw_headers)
            .request(@__sw_method, @__sw_url, **@__sw_http_opts)

          case response.content_type.mime_type
          when /json/i
            response = ::JSON.parse(response.to_s)
          else
            response = ::Capybara::Node::Simple.new(response.to_s)
          end
        end

        begin
          @__sw_tests.each { |test| test.call(response) }
        rescue ::RSpec::Expectations::ExpectationNotMetError => err
          __sw_fulfilled! if force
          raise(err)
        end

        __sw_fulfilled!
      end

      private

      def __sw_fulfilled!
        @__sw_fulfilled.call(@__sw_url) if @__sw_fulfilled.respond_to?(:call)
      end
    end
  end
end
