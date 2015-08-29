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
	dev.state = out
	inp = dev.state
	puts "Written #{bits(out)}, read #{bits(inp)}: #{(out & mask)==(inp & mask) ? 'ok' : 'failed'}"
end

def test_input(dev)
	inp = dev.state
	puts "Read #{bits(inp)}"
end

begin
	puts "#{io.name} v#{io.version} ##{io.serial_number}"
	puts

    io.open do |dev|
    	# Output test
    	ask "Attention: disconnect all stuff from IO device!"

    	# Set all lines to output direction
    	dev.directions = 0

    	# Check various patterns
    	test_output(dev, 0)
    	test_output(dev, 0xffff)
    	test_output(dev, 0x5a5a)
    	test_output(dev, dev.state ^ 0xffff)

    	puts "Setting line 1-4 to input direction"
    	dev.directions = 0x000f
    	test_output(dev, 0xffff, 0xfff0)
    	test_output(dev, 0xffff, 0xfff0)

    	# Input test
    	ask "All lines will be inputs now, open and shorten lines please"

    	dev.directions = 0xffff
    	io.on_change {|lines| puts "Read #{bits(lines)}"}

    	ask ""
    end
rescue Interrupt
end

# vim: et sw=4 ts=4