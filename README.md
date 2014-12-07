# SiteWatcher

I wrote this to notify me when the Wii U Gamecube controller adapter becomes
available.

## Usage

Here's an example script. I'm using this to monitor gamestop.com and bestbuy.com:

```ruby
require "site_watcher"

SiteWatcher.watch(every: 2) do
  # HTML
  page("http://www.gamestop.com/wii-u/accessories/wii-u-gamecube-adapter/115426") do
    # Use RSpec to describe your expectations.
    test do |page|
      # `page` is a `Capybara::Node::Simple`. See available matchers here:
      # http://www.rubydoc.info/github/jnicklas/capybara/Capybara/Node/Matchers
      expect(page).not_to have_selector("div.buy1 div.buttonna")
    end

    fulfilled do |url|
      # Call this block when your expectations are met. Here I send myself an email.
      IO.popen(
        [
          "/usr/bin/mail",
          "-s", "GC controller adapter is available!",
          "alexgenco@gmail.com"
        ], "w"
      ) { |io| io.puts(url) }
    end
  end

  # JSON
  page("http://www.bestbuy.com/api/1.0/product/summaries?skus=7522006") do
    test do |json|
      # `json` is a hash of the parsed JSON body.
      expect(
        json[0]["availability"]["ship"]["displayMessage"]
      ).not_to match(/not available/i)
    end
  end
end
```

This script will block until all expectations have been fulfilled.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/site_watcher/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
