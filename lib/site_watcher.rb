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
    @force = false
  end

  def watch(delay)
    capture_usr1 do
      loop do
        break if @pages.empty?
        force = @force
        @force &&= false

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

  def capture_usr1
    ::Signal.trap(:USR1) { @force = true }
    yield
  ensure
    ::Signal.trap(:USR1, "DEFAULT")
  end

  module DSL
    class Top
      attr_reader :pages

      def initialize
        @pages = []
      end

      def page(url, &block)
        page = Page.new(url)
        page.instance_eval(&block)
        @pages << page
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

      def __sw_run!(force=false)
        ::OpenURI.open_uri(@url) do |response|
          case response.content_type
          when /json/i
            page = ::JSON.parse(response.read)
          else
            page = ::Capybara::Node::Simple.new(response.read)
          end

          begin
            @tests.each { |test| test.call(page) }
          rescue ::RSpec::Expectations::ExpectationNotMetError => err
            __sw_fulfilled! if force
            raise(err)
          end

          __sw_fulfilled!
        end
      end

      private

      def __sw_fulfilled!
        @fulfilled.call(@url) if @fulfilled.respond_to?(:call)
      end
    end
  end
end
