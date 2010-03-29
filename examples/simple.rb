#! /usr/bin/env ruby
require 'ncursesw/ui'

begin

    $UI = Ncurses::UI.new :echo => false, :raw => true, :newline => false

    $UI.observe :input, lambda {|string|
        if string == '/quit'
            $UI.finalize
            Process.exit! 0
        end

        $UI.puts string.inspect
    }

    $UI.start
rescue Exception => e
    Ncurses.stdscr.mvaddstr 1, 0, "#{e.to_s}\n"
    Ncurses.stdscr.mvaddstr 3, 0, e.backtrace.join("\n")
    Ncurses.refresh

    sleep 5
end
