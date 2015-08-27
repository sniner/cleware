require_relative '../lib/sniner/cleware/cleware_libusb'

include Sniner::Cleware::Devices::TrafficLight::Colors

tl = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_LED).first

unless tl
    puts "No TRAFFICLIGHT found!"
    exit
end

tl.open do
    tl.red = true
    sleep 1
    tl.yellow = true
    sleep 1
    tl.red = false
    tl.yellow = false
    tl.green = true
    sleep 2
    tl.leds = YELLOW
    sleep 1
    tl.leds = RED
    sleep 2
    tl.leds = 0
end

# vim: et sw=4 ts=4