#!/usr/bin/env ruby -I./lib
#
# This script will watch gamestop.com until the "Not Available" button goes away
# on the Wii U Gamecube controller adapter page. When it does, it will email me.
#
# NOTE: You'll need to setup a mail server on your VPS: http://bit.ly/1y9RMs9

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
