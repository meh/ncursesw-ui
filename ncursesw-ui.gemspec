Gem::Specification.new {|s|
    s.name         = 'ncursesw-ui'
    s.version      = '0.0.1'
    s.author       = 'meh.'
    s.email        = 'meh.ffff@gmail.com'
    s.homepage     = 'http://github.com/meh/ncursesw-ui'
    s.platform     = Gem::Platform::RUBY
    s.description  = 'A simplified Ncurses UI.'
    s.summary      = 'A simplified Ncurses UI.'
    s.files        = Dir.glob('lib/**/*.rb')
    s.require_path = 'lib'
    s.has_rdoc     = true

    s.add_dependency('ncursesw')
}
