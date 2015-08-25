require_relative '../lib/sniner/cleware'

puts "== Devices found =="
Sniner::Cleware.devices.each {|d| puts d}

io = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_CONTACT).first
begin
    puts "Digital I/O"
    state = -1
    io.open do
        loop do
            s = io.state
            if s!=state
                p state = s
            end
            sleep(0.1)
        end
    end
rescue Interrupt
end if io

include Sniner::Cleware::Devices::TrafficLight::Colors

tl = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_LED)
if tl.length==1
    puts "\n== Switching lights on/off =="
    dev = tl.first
    dev.open do
        dev.red = true
        sleep 1
        dev.yellow = true
        sleep 1
        dev.red = false
        dev.yellow = false
        dev.green = true
        sleep 2
        dev.leds = YELLOW
        sleep 1
        dev.leds = RED
        sleep 2
        dev.leds = 0
        puts "done"
    end
elsif tl.length>0
    puts "\n== Multiple traffic lights =="
    tl = tl.map(&:open).compact
    seq = [RED, RED|YELLOW, GREEN, YELLOW]
    20.times do |i|
        tl.each {|a| a.leds = seq[i % seq.length]}
        sleep(1)
    end
    tl.map(&:close)
    puts "done"
end

# vim: et sw=4 ts=4