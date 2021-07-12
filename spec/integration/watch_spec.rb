require "fiber"
require "logger"
require "stringio"

RSpec.describe "SiteWatcher.watch" do
  it "watches an HTML page" do
    _fulfilled = false

    expect do |y|
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/html") do
          test do |html|
            expect(html).to have_selector("body h1")
          end

          fulfilled(&y)
        end
      end
    end.to yield_control
  end

  it "watches a JSON endpoint" do
    _fulfilled = false

    expect do |y|
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/get") do
          test do |json|
            expect(json["headers"]["Host"]).to eq("httpbin.org")
          end

          fulfilled(&y)
        end
      end
    end.to yield_control
  end

  it "watches an XML endpoint" do
    _fulfilled = false

    expect do |y|
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/xml") do
          test do |xml|
            expect(xml).to have_xpath(".//slideshow/slide")
          end

          fulfilled(&y)
        end
      end
    end.to yield_control
  end

  it "watches an endpoint with POST" do
    expect do |y|
      SiteWatcher.watch(:every => 0) do
        page("https://httpbin.org/post", method: :post, body: "foobar") do
          test do |json|
            expect(json["data"]).to eq("foobar")
          end

          fulfilled(&y)
        end
      end
    end.to yield_control
  end

  it "watches multiple pages" do
    expect do |y|
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/html") do
          test do |html|
            expect(html).to have_selector("body h1")
          end

          fulfilled(&y)
        end

        page("http://httpbin.org/get") do
          test do |json|
            expect(json["headers"]["Host"]).to eq("httpbin.org")
          end

          fulfilled(&y)
        end
      end
    end.to yield_successive_args(/html$/, /get$/)
  end

  it "retries when expectations aren't fulfilled" do
    tries = 0

    expect do |y|
      fiber = Fiber.new(0) do |n|
        SiteWatcher.watch(:every => 0) do
          page("http://httpbin.org/html") do
            test do |html|
              Fiber.yield(tries += 1)
              expect(html).not_to have_selector("body")
            end

            fulfilled(&y)
          end
        end
      end

      expect(fiber.resume).to eq(1)
      expect(fiber.resume).to eq(2)
    end.not_to yield_control
  end

  it "continues running fulfilled events using remove_on_fulfillment=false" do
    tries = 0

    expect do |y|
      fiber = Fiber.new do
        SiteWatcher.watch(:every => 0) do
          page("http://httpbin.org/html") do
            remove_on_fulfillment false

            test do |html|
              Fiber.yield(tries += 1)
              expect(html).to have_selector("body")
            end

            fulfilled(&y)
          end
        end
      end

      expect(fiber.resume).to eq(1)
      expect(fiber.resume).to eq(2)

      fiber.resume
    end.to yield_successive_args(/html$/, /html$/)
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

  it "registers before hooks" do
    fiber = Fiber.new do
      SiteWatcher.watch(:every => 0) do
        before do
          Fiber.yield(0)
        end

        before do
          Fiber.yield(1)
        end

        page("http://httpbin.org/html") do
          test do
            Fiber.yield(2)
          end
        end
      end
    end

    expect(fiber.resume).to eq(0)
    expect(fiber.resume).to eq(1)
    expect(fiber.resume).to eq(2)
  end

  it "registers after hooks" do
    fiber = Fiber.new do
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/html") do
          test do
            Fiber.yield(0)
          end
        end

        after do
          Fiber.yield(1)
        end

        after do
          Fiber.yield(2)
        end
      end
    end

    expect(fiber.resume).to eq(0)
    expect(fiber.resume).to eq(1)
    expect(fiber.resume).to eq(2)
  end

  it "registers custom request fetching" do
    fiber = Fiber.new do
      SiteWatcher.watch(:every => 0) do
        page("http://httpbin.org/html") do
          fetch do |url|
            Fiber.yield(url)
            {foo: "bar"}
          end

          test do |response|
            Fiber.yield(response)
          end
        end
      end
    end

    expect(fiber.resume).to eq("http://httpbin.org/html")
    expect(fiber.resume).to eq(foo: "bar")
  end
end
