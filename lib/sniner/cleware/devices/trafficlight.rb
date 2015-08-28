# encoding: utf-8
#
# trafficlight.rb - Cleware traffic light
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    28.08.2015
# Version::  0.1
#

require 'timeout'

require_relative '../products'

module Sniner

    module Cleware

        class TrafficLight < DeviceConnection
            SUPPORTED_PRODUCTS = [PRODUCT_LED]

            module Colors
                RED     = 0x01
                YELLOW  = 0x02
                GREEN   = 0x04
                NONE    = 0x00
                ALL     = 0x07
            end

            def initialize(dev)
                super
                @impl = dev.devinfo.version<100 ? OldCtl.new(self) : NewCtl.new(self)
            end

            # Controller-independent stuff
            class Impl
                attr_reader :internal_state

                MAP = {
                    TrafficLight::Colors::RED => 0x10,
                    TrafficLight::Colors::YELLOW => 0x11,
                    TrafficLight::Colors::GREEN => 0x12
                }

                def initialize(dev)
                    @dev = dev
                    @internal_state = 0
                end

                def switch_internal_state(color, on)
                    if on
                        @internal_state |= color
                    else
                        @internal_state &= (color ^ TrafficLight::ALL)
                    end
                end

                def switch(color, on=true)
                    if MAP[color]
                        switch_internal_state(color, on)
                        @dev.write(Device::REPORT_ID, 0, MAP[color], on ? 1 : 0)
                    end
                end

                def state
                    @internal_state
                end
            end

            # Traffic light with new controller (version >= 106)
            class NewCtl < Impl
                def state
                    @state_seq ||= 1
                    begin
                        @dev.write(Device::REPORT_ID, 5, 2, @state_seq)
                        Timeout.timeout(0.5) do
                            loop do
                                res = @dev.device.devinfo.read(6, 1000)
                                # FIXME: Or just 'res = @dev.read(6)'?
                                if res
                                    bits = res[0]
                                    next if (bits & 0x80) == 0
                                    next if (res[1] & 0xf8) != (@state_seq << 3)
                                    return (bits&1) | ((bits>>1)&2) | ((bits>>2)&4)
                                end
                            end
                        end
                    rescue Timeout::Error
                        nil
                    ensure
                        @state_seq = (@state_seq + 1) & 0x1f
                    end
                end
            end

            # Traffic light with old controller (i.e. version 29)
            class OldCtl < Impl
                # TODO: dead slow and unreliable -> internal_state used instead
                def read_state
                    sleep(1) # !!!
                    3.times { @dev.read(6) }
                    res = @dev.read(6)
                    if res
                        bits = res[0]
                        if (bits & 0x80) != 0
                            (bits&1) | ((bits>>1)&2) | ((bits>>2)&4)
                        else
                            0
                        end
                    end
                end
            end

            def leds=(colors)
                [RED, YELLOW, GREEN].each do |c|
                    @impl.switch(c, (colors&c)!=0)
                end
            end

            alias :set :leds=

            def red=(state)
                @impl.switch(RED, state)
            end

            def yellow=(state)
                @impl.switch(YELLOW, state)
            end

            def green=(state)
                @impl.switch(GREEN, state)
            end

            def leds
                @impl.state || 0
            end

            alias :get :leds
            alias :state :leds

            def red?
                (leds & RED) != 0
            end

            def yellow?
                (leds & YELLOW) != 0
            end

            def green?
                (leds & GREEN) != 0
            end
        end

    end

end

# vim: et sw=4 ts=4