#! /usr/bin/env ruby
require 'ncursesw/ui'

$UI = Ncurses::UI.new :echo => false, :raw => true, :newline => false
$UI.add :window

$UI.observe :input, lambda {|string|
    Ncurses.move 0, 0
    Ncurses.addstr string.inspect
    $UI.input.focus!
    Ncurses.refresh

    if string == '/quit'
        $UI.finalize
        Process.exit! 0
    end
}

$UI.start
