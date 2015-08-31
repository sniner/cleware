require_relative '../lib/sniner/cleware'

include Sniner::Cleware::TrafficLight::Colors

tl = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_LED).first

unless tl
    puts "No TRAFFICLIGHT found!"
    exit
end

puts "#{tl.name} v#{tl.version} ##{tl.serial_number}"

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

# vim: et sw=4 ts=4