require_relative '../lib/sniner/cleware'

io = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_CONTACT).first

unless io
    puts "No CONTACT found!"
    exit
end

def ask(msg)
    $stdout.write "#{msg} (Hit Ctrl-C to continue)"
    sleep(3600)
    exit
rescue Interrupt
    puts
    true
end

def bits(val)
    val ? sprintf('%016b', val) : "NULL"
end

def test_output(dev, out, mask=0xffff)
    dev.lines = out
    inp, dir = dev.state
    puts "Written #{bits(out)}, read #{bits(inp)}, dir #{bits(dir)}: #{(out & mask)==(inp & mask) ? 'ok' : 'failed'}"
end

def test_single(dev, line, on, mask=0xffff)
    dev[line] = on
    inp = dev[line]
    puts "Written #{line}=#{on}, read #{inp}, lines #{bits(dev.lines)}: #{on == inp ? 'ok' : 'failed'}"
end


def test_input(dev)
    inp, dir = dev.state
    puts "Read #{bits(inp)}, dir #{bits(dir)}"
end

begin
    puts "#{io.name} v#{io.version} ##{io.serial_number}"
    puts

    io.open do |dev|
        puts "This device has #{dev.count} lines."
        puts "Current direction bitmask: #{dev.directions}"

        # Output test
        ask "Attention: disconnect all stuff from IO device!"

        # Set all lines to output direction
        dev.directions = 0

        # Check various patterns
        test_output(dev, 0)
        test_single(dev, 4, true)
        test_output(dev, 0xffff)
        test_single(dev, 4, false)
        test_output(dev, 0x5a5a)
        test_output(dev, dev.lines ^ 0xffff)

        puts "Setting line 1-4 to input direction"
        dev.directions = 0x000f
        test_output(dev, 0xffff, 0xfff0)
        test_output(dev, 0xffff, 0xfff0)

        # Input test
        ask "All lines will be inputs now, open and shorten lines please"

        dev.directions = 0xffff
        io.on_change {|lines| puts "Read #{bits(lines[0])}"}

        ask "Waiting for input"
    end
rescue Interrupt
end

# vim: et sw=4 ts=4