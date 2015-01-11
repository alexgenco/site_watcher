require "timeout"
require "fiber"
require "stringio"
require "logger"

RSpec.describe "SiteWatcher.watch" do
  it "watches an HTML page" do
    _fulfilled = false

    SiteWatcher.watch(:every => 0) do
      page("http://httpbin.org/html") do
        test do |html|
          expect(html).to have_selector("body h1")
        end

        fulfilled do
          _fulfilled = true
        end
      end
    end

    expect(_fulfilled).to be(true)
  end

  it "watches a JSON endpoint" do
    _fulfilled = false

    SiteWatcher.watch(:every => 0) do
      page("http://httpbin.org/get") do
        test do |json|
          expect(json["headers"]["Host"]).to eq("httpbin.org")
        end

        fulfilled do
          _fulfilled = true
        end
      end
    end

    expect(_fulfilled).to be(true)
  end

  it "watches an XML endpoint" do
    _fulfilled = false

    SiteWatcher.watch(:every => 0) do
      page("http://httpbin.org/xml") do
        test do |xml|
          expect(xml).to have_xpath(".//slideshow/slide")
        end

        fulfilled do
          _fulfilled = true
        end
      end
    end

    expect(_fulfilled).to be(true)
  end

  it "watches multiple pages" do
    _fulfilled = []

    SiteWatcher.watch(:every => 0) do
      page("http://httpbin.org/html") do
        test do |html|
          expect(html).to have_selector("body h1")
        end

        fulfilled do
          _fulfilled << :html
        end
      end

      page("http://httpbin.org/get") do
        test do |json|
          expect(json["headers"]["Host"]).to eq("httpbin.org")
        end

        fulfilled do
          _fulfilled << :json
        end
      end
    end

    expect(_fulfilled).to eq([:html, :json])
  end

  it "retries when expectations aren't fulfilled" do
    _fulfilled = false
    _tries = 0

    fiber = Fiber.new do
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/html") do
          test do |html|
            Fiber.yield(_tries += 1)
            expect(html).not_to have_selector("body")
          end

          fulfilled do
            _fulfilled = true
          end
        end
      end
    end

    expect(fiber.resume).to eq(1)
    expect(fiber.resume).to eq(2)
    expect(_fulfilled).to be(false)
  end

  it "logs on exceptions" do
    stderr = StringIO.new
    logger = Logger.new(stderr)

    fiber = Fiber.new do
      SiteWatcher.watch(:every => 0, :logger => logger) do
        page("http://httpbin.org/html") do
          test do |html|
            Fiber.yield
            raise RuntimeError, "BOOM"
          end
        end
      end
    end

    fiber.resume

    expect {
      fiber.resume
    }.to change { stderr.string }.from("").to(/BOOM/)
  end
end
