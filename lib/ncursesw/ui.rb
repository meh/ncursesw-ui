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
                @UI.input.focus!
                self.refresh
            end
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

    # I can't find a way to keep the focus on the input field without wasting cycles on
    # non blocking getch.
    class Input
        attr_reader   :UI, :raw, :history
        attr_accessor :utf8, :max, :prompt

        @@symbols = {
            :ALT       => 27,
            :BACKSPACE => 127,

            :ARROWS => {
                :UP   => { :SHIFT => 527 },
                :DOWN => { :SHIFT => 513 },
            },
        }

        def initialize (ui, options={})
            @UI    = ui
            @utf8  = (options[:utf8].nil?) ? true : options[:utf8]

            @cursor   = 0
            @position = 0
            @data     = String.new
            @history  = []
            @current  = 0
            @prompt   = String.new

            if options[:max]
                @max = options[:max]
            else
                @max = 42
            end

            @raw = WINDOW.new(1, Ncurses.COLS, Ncurses.LINES - 1, 0)
            @raw.keypad true
            @raw.nodelay true
        end

        def finalize
        end

        def position
            { :x => @raw.getbegx, :y => @raw.getbegy }
        end

        def size
            { :width => @raw.getmaxx, :height => @raw.getmaxy }
        end

        def focus!
            @raw.move 0, @cursor
        end

        def getch
            while (result = @raw.getch) < 0 do
                sleep 0.01
                next
            end

            return result
        end

        def readChar
            result = {
                :ALT   => false,
                :CTRL  => false,
                :SHIFT => false,
                :value => nil,
            }

            value = self.getch

            if value == @@symbols[:ALT]
                result[:ALT] = true

                value = self.getch
            end

            case value

            when 1 .. 26
                if value == 10
                    value = :ENTER
                elsif value == 9
                    value = :TAB
                else
                    result[:CTRL] = true
                    value += 64
                end

            when 31
                result[:CTRL]  = true
                result[:value] = '_'

            end

            if result[:CTRL]
                if value.is_a?(Fixnum)
                    result[:value] = value.chr.to_sym
                else
                    result[:value] = value
                end

                return result
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
                        case UI.bin(value)

                        when /^0/
                            result[:value].concat(value)

                        when /^110/
                            result[:value].concat(value)
                            result[:value].concat(self.getch)

                        when /^1110/
                            result[:value].concat(value)
                            result[:value].concat(self.getch)
                            result[:value].concat(self.getch)

                        when /^11110/
                            result[:value].concat(value)
                            result[:value].concat(self.getch)
                            result[:value].concat(self.getch)
                            result[:value].concat(self.getch)

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
            while char = self.readChar
                if char[:value].is_a?(String) && !char[:ALT] && !char[:CTRL]
                    self.put char[:value]
                else
                    if char[:value] == :ENTER
                        if @data.empty?
                            line = String.new
                            break
                        end

                        if @history.length > @max
                            @history.shift
                        end

                        if @history.last != @data
                            @history.push @data.clone
                        end

                        @UI.fire :input, @data.clone
                        line     = @data.clone
                        @current += 1

                        self.clear
                        break
                    elsif char[:value] == :BACKSPACE
                        if @data.length > 0
                            self.deleteAt(@position - 1, true)
                        end
                    elsif char[:value] == :CANC
                        if @position < @data.length
                            self.deleteAt(@position)
                        end
                    elsif char[:value] == :LEFT
                        if @cursor > 0
                            @cursor -= 1
                        end
                    elsif char[:value] == :RIGHT
                        if @cursor < UI.realLength(@data)
                            @cursor += 1
                        end
                    elsif char[:value] == :HOME
                        @cursor   = 0
                        @position = 0
                    elsif char[:value] == :END
                        @cursor   = UI.realLength(@data)
                        @position = @data.length
                    elsif char[:value] == :UP
                        if @current > 0
                            if @current == @history.length && @history.last != @data && !@data.empty?
                                @history.push @data
                            end

                            @current -= 1
                            @data     = @history[@current].clone
                            @cursor   = UI.realLength(@data)
                            @position = @data.length
                        end
                    elsif char[:value] == :DOWN
                        if @current < @history.length-1
                            @current += 1
                            @data     = @history[@current].clone
                            @cursor   = UI.realLength(@data)
                            @position = @data.length
                        else
                            if !@data.empty?
                                @current += 1
                                @data     = String.new
                                @cursor   = 0
                                @position = 0
                            end
                        end
                    elsif char[:value] == :C && char[:CTRL]
                        self.put "\x03"
                    elsif char[:value] == :B && char[:CTRL]
                        self.put "\x02"
                    elsif char[:value] == :V && char[:CTRL]
                        self.put "\x16"
                    elsif char[:value] == :_ && char[:CTRL]
                        self.put "\x1F"
                    end

                    self.refresh
                        
                    @UI.fire(:button, char)
                end
            end

            return line
        end

        def put (value)
            @data.insert(@position, value)

            if !UI.isSpecial(@data, @position)
                @cursor += 1
            end

            @position += 1

            self.refresh

            return value
        end

        def clear
            @data.clear
            @cursor   = 0
            @position = 0

            @raw.mvaddstr(0, 0, ' ' * (self.size[:width] - @prompt.length))
            @raw.move(0, 0)
        end

        def refresh
            position = self.position
            size     = self.size

            UI.mvaddstr(@raw, 0, 0, @data)
            @raw.mvaddstr(0, UI.realLength(@data), ' ' * (size[:width] - UI.realLength(@data) - @prompt.length))
            @raw.move(0, UI.realCursor(@data, @cursor))
        end

        def deleteAt (position, change=false)
            if position >= 0 && position < @data.length
                if change && !UI.isSpecial(@data, position)
                    @cursor   -= 1
                    @position -= 1 
                end

                @data[position, 1] = ''
            end
        end

    end

    attr_reader   :input, :windows, :statutes, :options
    attr_accessor :focused, :private

    def initialize (options={})
        Ncurses.initscr

        UI.initColors

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
            @input.readLine
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

    @@colors = {
        :White      => 0,
        :Black      => 1,
        :Blue       => 2,
        :Green      => 3,
        :LightRed   => 4,
        :Red        => 5,
        :Purple     => 6,
        :Brown      => 7,
        :Yellow     => 8,
        :LightGreen => 9,
        :Azure      => 10,
        :Cyan       => 11,
        :LightBlue  => 12,
        :Magenta    => 13,
        :Gray       => 14,
        :LightGray  => 15,

        # order is important
        :Normal => [1, 5, 3, 7, 2, 6, 15],
        :Light  => [14, 4, 9, 8, 12, 13, 0],

        :Pairs => {},
    }

    def self.colors
        @@colors
    end

    def self.color (*args)
        if args.first.is_a?(Array)
            fg, bg = args.shift
        else
            fg, bg = args
        end

        if fg.is_a?(String)
            if fg.empty?
                fg = -1
            else
                fg = fg.to_i
            end
        end

        if bg.is_a?(String)
            if bg.empty?
                bg = -1
            else
                bg = bg.to_i
            end
        end

        if !fg || fg < 0
            fg = -1
        else
            fg %= 16
        end

        if !bg || bg < 0
            bg = -1
        else
            bg %= 16
        end

        color = 0

        if fgIndex = @@colors[:Light].index(fg)
            color |= A_BOLD
        else
            fgIndex = @@colors[:Normal].index(fg) || -1
        end

        if bgIndex = @@colors[:Light].index(bg)
            color |= A_BLINK
        else
            bgIndex = @@colors[:Normal].index(bg) || -1
        end

        if pair = @@colors[:Pairs][[fgIndex, bgIndex]]
            color |= Ncurses.COLOR_PAIR(pair)
        end

        return color
    end

    def self.initColors
        Ncurses.start_color
        Ncurses.use_default_colors

        offset = 1

        (-1 .. 7).to_a.permutation(2).each {|pair|
            Ncurses.init_pair(offset, pair[0], pair[1])

            @@colors[:Pairs][pair] = offset
            offset                += 1
        }
    end

    def self.clean (string)
        string = string.clone
        string.gsub!(/[\x02\x16\x1F]/, '')
        string.gsub!(/\x03((\d{1,2})?(,\d{1,2})?)?/, '')

        return string
    end

    def self.isSpecial (string, position=0)
        if string[position, 1].match(/^[,\d]$/)

        else
            string.match(/^.{#{position}}[\x02\x16\x1F]/) || string.match(/^.{#{position}}\x03((\d{1,2})?(,\d{1,2})?)?/)
        end
    end

    def self.realLength (string)
        string = UI.clean(string)
        result = 0

        string.each_char {|char|
            char.force_encoding 'ASCII-8BIT'

            if char.length > 1
                result += 2
            else
                result += 1
            end
        }

        return result
    end

   def self.realCursor (string, position)
        string = UI.clean(string)
        result = 0
        offset = 0

        string.each_char {|char|
            if offset >= position
                break
            end

            char.force_encoding 'ASCII-8BIT'

            if char.length > 1
                result += 2
            else
                result += 1
            end

            offset += 1
        }

        return result
    end

    def self.realPosition (string, position)
        result = 0
        offset = 0

        string.each_char {|char|
            if UI.isSpecial(char)

            end
        }

        return result
    end

    def self.bin (n)
        [n].pack('C').unpack('B8')[0]
    end

    def self.mvaddstr (window, y, x, string)
        on = {
            :bold      => false,
            :reverse   => false,
            :underline => false,
        }

        colorize = nil
        type     = 0
        current  = 0

        string.each_char {|char|
            if colorize || char == "\x03"
                if char == "\x03"
                    if colorize
                        window.attroff UI.color(colorize)
                        colorize = false
                    else
                        colorize = ['', '']
                        type     = 0
                    end
                else
                    if char == ','
                        type = 1
                    else
                        if !char.match(/^\d$/)
                            if color = UI.color(colorize)
                                window.attron(color)
                            end

                            if colorize[1].empty? && type == 1
                                window.mvaddstr(0, current, ',')
                                current += 1
                            end

                            window.mvaddstr(0, current, char)
                            current += 1
                        else
                            colorize[type] << char
                        end
                    end
                end
            elsif char == "\x02"
                if on[:bold]
                    window.attroff A_BOLD
                    on[:bold] = false
                else
                    window.attron A_BOLD
                    on[:bold] = true
                end
            elsif char == "\x16"
                if on[:reverse]
                    window.attroff A_REVERSE
                    on[:reverse] = false
                else
                    window.attron A_REVERSE
                    on[:reverse] = true
                end
            elsif char == "\x1F"
                if on[:underline]
                    window.attroff A_UNDERLINE
                    on[:underline] = false
                else
                    window.attron A_UNDERLINE
                    on[:underline] = true
                end
            else
                window.mvaddstr(0, current, char)
                current += 1
            end
        }

        attrs = []
        pair  = []

        window.attr_get(attrs, pair, nil)
        window.attroff(attrs.shift | pair.shift)
    end
end

end
