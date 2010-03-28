#! /usr/bin/env ruby
require 'ncursesw/ui'

$UI = Ncurses::UI.new :echo => false, :raw => true, :newline => false

$UI.observe :input, lambda {|string|
    if string == '/quit'
        $UI.finalize
        Process.exit! 0
    end

    $UI.puts string.inspect
}

$UI.start
