#!/usr/bin/env ruby -I./lib

require "site_watcher"

SiteWatcher.watch do
  page("http://www.gamestop.com/wii-u/accessories/wii-u-gamecube-adapter/115426") do
    test do
      css.excludes("div.buy1 div.buttonna")
    end

    fulfilled do
      IO.popen(
        [
          "/usr/bin/mail",
          "-s", "GC controller adapter is available!",
          "alexgenco@gmail.com"
        ], "w"
      ) { |io| io.puts(url) }
    end
  end
end
