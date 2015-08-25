require_relative '../lib/sniner/cleware'

io = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_CONTACT).first

unless io
    puts "No CONTACT found!"
    exit
end

begin
    puts "Hit Ctrl-C to terminate"

    io.on_change {|s| puts "State: #{s}"}

    sleep(3600)
rescue Interrupt
end

# vim: et sw=4 ts=4