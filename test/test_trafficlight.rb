require_relative '../lib/sniner/cleware'

include Sniner::Cleware::TrafficLight::Colors

def single(tl)
    tl.open do |dev|
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
    end
end

def multiple(devices)
    tl = devices.map {|dev| dev.open}
    [RED, YELLOW, GREEN].each do |color|
        tl.each do |l|
            l.leds = color
            sleep 0.5
            l.leds = 0
        end
    end
ensure
    tl.each {|tl| tl.close} if tl
end

devices = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_LED)

if devices.empty?
    puts "No TRAFFICLIGHT found!"
    exit
end

devices.each {|dev| puts "#{dev.name} v#{dev.version} ##{dev.serial_number} #{dev.path}"}

if devices.length==1
    single(devices.first)
else
    multiple(devices)
end

# vim: et sw=4 ts=4