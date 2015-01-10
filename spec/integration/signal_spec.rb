RSpec.describe "signal handling" do
  describe "USR1" do
    it "signals to run the fulfilled block of the next test" do
      _fulfilled = 0

      fiber = Fiber.new do
        SiteWatcher.watch(:every => 0) do
          page("http://httpbin.org/html") do
            test do |html|
              Fiber.yield
              expect(html).not_to have_selector("body")
            end

            fulfilled do
              _fulfilled += 1
            end
          end
        end
      end

      fiber.resume
      expect(_fulfilled).to be(0)

      ::Process.kill(:USR1, $$)
      fiber.resume

      expect {
        fiber.resume
      }.to change { _fulfilled }.by(1)

      expect {
        fiber.resume
      }.not_to change { _fulfilled }
    end
  end
end
