# Copyleft meh. [http://meh.doesntexist.org | meh.ffff@gmail.com]
#
# ncursesw-ui is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ncursesw-ui is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with ncursesw-ui. If not, see <http://www.gnu.org/licenses/>.

require 'thread'
require 'ncursesw'

class Proc
    def bind (other)
        Proc.new {|*args|
            other.instance_exec(*args, &self)
        }
    end
end

module Ncurses

class UI
    class Window
        class Buffer
            attr_reader   :data
            attr_accessor :position

            def initialize
                @data     = []
                @position = 0
            end
        end

        attr_reader   :UI, :raw, :options
        attr_accessor :private

        def initialize (ui, options={})
            @UI      = ui
            @options = options

            @raw = WINDOW.new(0, 0, 0, 0)

            self.adapt
            self.focused = options[:focused]
        end

        def finalize
        end

        def adapt
            Ncurses.mvwin @raw, @UI.top, 0
            Ncurses.wresize @raw, Ncurses.LINES - @UI.bottom - @UI.top, Ncurses.COLS
        end

        def puts (string, refresh=true)
            @raw.addstr "#{string}\n"

            if refresh
                self.refresh
            end

            @UI.input.focus!
        end

        def focused?
            @focused
        end

        def focused= (value)
            @focused = value

            if value
                @UI.focused = self
                @raw.clear
                @raw.mvaddstr(0, 0, self.buffer(@raw.getmaxy))
                self.refresh
            end
        end

        def focus!
            self.focused = true
        end

        def buffer (lines)
            @buffer
            String.new
        end

        def refresh
            @raw.refresh
        end
    end

    class Status
        attr_reader   :UI, :raw, :options, :position

        def initialize (ui, options={})
            @UI      = ui
            @options = options

            if !options[:width]
                options[:width] = Ncurses.COLS
            end
    
            if !options[:position]
                options[:position] = :bottom
            end

            @position = options[:position]

            if options[:position] == :top
                y = 0
            else
                y = Ncurses.LINES - 2 - @UI.statutes.length
            end

            @raw = WINDOW.new(1, options[:width], 0, y)
        end

        def finalize
            
        end
    end

    class Input
        attr_reader   :UI, :raw
        attr_accessor :utf8

        @@symbols = {
            :ALT       => 27,
            :BACKSPACE => 127,

            :ARROWS => {
                :UP   => { :SHIFT => 527 },
                :DOWN => { :SHIFT => 513 },
            },
        }

        def initialize (ui, options={})
            @UI   = ui
            @utf8 = true

            @cursor = 0
            @data   = String.new

            @raw = WINDOW.new(1, Ncurses.COLS, Ncurses.LINES - 1, 0)
            @raw.keypad true
        end

        def finalize
        end

        def position
            { :x => @raw.getbegx, :y => @raw.getbegy }
        end

        def focus!
            @raw.move 0, @cursor
        end

        def readChar
            result = {
                :ALT   => false,
                :CTRL  => false,
                :SHIFT => false,
                :value => nil,
            }

            value = @raw.getch

            if value == @@symbols[:ALT]
                result[:ALT] = true

                value = @raw.getch
            end

            if value <= 26
                if value == 10
                    value = :ENTER
                elsif value == 9
                    value = :TAB
                else
                    result[:CTRL] = true
                    value += 64
                end
            end

            case value

            when Ncurses::KEY_ENTER, :ENTER
                result[:value] = :ENTER

            when :TAB
                result[:value] = :TAB

            when Ncurses::KEY_LEFT, Ncurses::KEY_SLEFT
                if value == Ncurses::KEY_SLEFT
                    result[:SHIFT] = true
                end

                result[:value] = :LEFT

            when Ncurses::KEY_UP, @@symbols[:ARROWS][:UP][:SHIFT]
                if value == @@symbols[:ARROWS][:UP][:SHIFT]
                    result[:SHIFT] = true
                end

                result[:value] = :UP

            when Ncurses::KEY_DOWN, @@symbols[:ARROWS][:DOWN][:SHIFT]
                if value == @@symbols[:ARROWS][:UP][:SHIFT]
                    result[:SHIFT] = true
                end

                result[:value] = :DOWN

            when Ncurses::KEY_RIGHT, Ncurses::KEY_SRIGHT
                if value == Ncurses::KEY_SRIGHT
                    result[:SHIFT] = true
                end

                result[:value] = :RIGHT

            when Ncurses::KEY_BACKSPACE, @@symbols[:BACKSPACE]
                result[:value] = :BACKSPACE

            when Ncurses::KEY_HOME, Ncurses::KEY_SHOME
                if value == Ncurses::KEY_SHOME
                    result[:SHIFT] = true
                end

                result[:value] = :HOME

            when Ncurses::KEY_END, Ncurses::KEY_SEND
                if value == Ncurses::KEY_SEND
                    result[:SHIFT] = true
                end

                result[:value] = :END

            when Ncurses::KEY_NPAGE
                result[:value] = :PAGDOWN

            when Ncurses::KEY_PPAGE
                result[:value] = :PAGUP

            when Ncurses::KEY_DC
                result[:value] = :CANC

            else
                begin
                    result[:value] = String.new
                    result[:value].force_encoding('ASCII-8BIT')

                    if self.utf8
                        case Input.bin(value)

                        when /^0/
                            result[:value].concat(value)

                        when /^110/
                            result[:value].concat(value)
                            result[:value].concat(@raw.getch)

                        when /^1110/
                            result[:value].concat(value)
                            result[:value].concat(@raw.getch)
                            result[:value].concat(@raw.getch)

                        when /^11110/
                            result[:value].concat(value)
                            result[:value].concat(@raw.getch)
                            result[:value].concat(@raw.getch)
                            result[:value].concat(@raw.getch)

                        end

                        result[:value].force_encoding('UTF-8')
                    else
                        result[:value].concat(value)
                    end
                rescue
                    result[:value] = nil
                end
            end

            return result
        end

        def readLine
            line = String.new

            while char = self.readChar
                # $UI.puts "#{char[:CTRL] ? 'CTRL ' : ''}#{char[:ALT] ? 'ALT ' : ''}#{char[:SHIFT] ? 'SHIFT ' : ''}#{char[:value]}"

                if char[:value].is_a?(String) && !char[:ALT] && !char[:CTRL]
                    line << self.put(char[:value])
                    @cursor += 1
                else
                    if char[:value] == :ENTER
                        self.clear
                        break
                    elsif char[:value] == :BACKSPACE
                        @data.sub!(/(.{#{@cursor}})./, '$1')
                    else
                        @UI.fire(:button, char)
                    end
                end
            end

            return line
        end

        def put (value)
            @data.insert(@cursor, value)
            self.refresh

            return value
        end

        def clear
            @data.clear
            @cursor = 0

            @raw.mvaddstr(0, 0, ' '*Ncurses.COLS)
            @raw.move(0, 0)
        end

        def refresh
            position = self.position

            @raw.mvaddstr(0, 0, @data)
            @raw.move(0, @cursor+1)
        end

        def self.bin (n)
            [n].pack('C').unpack('B8')[0]
        end
    end

    attr_reader   :input, :windows, :statutes, :options
    attr_accessor :focused, :private

    def initialize (options={})
        Ncurses.initscr

        @options = options

        if options[:raw] == true
            Ncurses.raw
        elsif options[:raw] == false
            Ncurses.noraw
        end

        if options[:echo] == true
            Ncurses.echo
        elsif options[:echo] == false
            Ncurses.noecho
        end

        if options[:cbreak] == true
            Ncurses.cbreak
        elsif options[:cbreak] == false
            Ncurses.nocbreak
        end

        if options[:newline] == true
            Ncurses.nl
        elsif options[:newline] == false
            Ncurses.nonl
        end

        if !options[:input]
            options[:input] = {}
        end

        @events   = {}
        @queue    = Queue.new
        @handling = false

        @windows  = []
        @statuses = []

        (self.add(:window)).focus!
        @input = Input.new(self, options[:input])
    end

    def finalize
        if !options[:echo]
            Ncurses.echo
        end

        if options[:raw]
            Ncurses.noraw
        end

        if !options[:cbreak]
            Ncurses.nocbreak
        end

        if !options[:newline]
            Ncurses.nl
        end

        @windows.each {|window|
            window.finalize
        }

        @statuses.each {|status|
            status.finalize
        }

        @input.finalize

        Ncurses.endwin
    end

    def start
        loop do
            self.fire(:input, @input.readLine)
        end
    end

    def add (element, args=[])
        if element.is_a?(Symbol)
            if element == :window
                element = Window.new self, *args
            elsif element == :status
                element = Status.new self, *args
            end
        end

        if element.is_a?(Window)
            @windows.push element
        elsif element.is_a?(Status)
            @statuses.push element
        end

        return element
    end

    def top
        result = 0

        @statuses.each {|status|
            if status.position == :top
                result += 1
            end
        }

        return result
    end

    def bottom
        result = 1

        @statuses.each {|status|
            if status.position == :top
                result += 1
            end
        }

        return result

    end

    def puts (*args)
        self.focused.puts *args
    end

    def observe (name, callback)
        if !@events[name]
            @events[name] = []
        end

        if callback.is_a?(Proc)
            @events[name].push(callback.bind(self))
        elsif callback.is_a?(Method)
            @events[name].push(callback.unbind.bind(self))
        elsif callback.is_a?(UnboundMethod)
            @events[name].push(callback.bind(self))
        end
    end

    def fire (name, *args)
        @queue.push({ :name => name, :arguments => args })

        if @handling
            return
        end

        self.handle
    end

    def handle
        @handling = true

        Thread.new {
            while event = @queue.pop rescue nil
                if !@events[event[:name]]
                    next
                end

                @events[event[:name]].each {|callback|
                    callback.call(*event[:arguments]) rescue nil
                }
            end

            @handling = false
        }
    end
end

end
