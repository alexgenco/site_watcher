RSpec.describe SiteWatcher do
  it "handles a passing test" do
    url = "http://www.gamestop.com/wii-u/accessories/wii-u-gamecube-adapter/115426"

    watcher = SiteWatcher.new(url) do |page|
      page.css.includes("div.buy1 div.buttonna")
    end

    success_yield = nil
    failure_yield = nil

    watcher.watch do |result|
      result.success do |*args|
        success_yield = args
      end

      result.failure do |*args|
        failure_yield = args
      end
    end

    expect(success_yield).to eq([url])
    expect(failure_yield).to be_nil
  end
end
