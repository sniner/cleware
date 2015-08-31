# encoding: utf-8
#
# trafficlight.rb - Cleware traffic light
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    31.08.2015
# Version::  0.2
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
                @internal_state = 0
            end

            def leds=(colors)
                [Colors::RED, Colors::YELLOW, Colors::GREEN].each do |c|
                    set_led(c, (colors&c)!=0)
                end
            end

            alias :set :leds=

            def red=(state)
                set_led(RED, state)
            end

            def yellow=(state)
                set_led(YELLOW, state)
            end

            def green=(state)
                set_led(GREEN, state)
            end

            def leds
                get_leds || 0
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

        private
            MAP = {
                Colors::RED     => 0x10,
                Colors::YELLOW  => 0x11,
                Colors::GREEN   => 0x12
            }

            def set_led(color, on=true)
                if MAP[color]
                    if on
                        @internal_state |= color
                    else
                        @internal_state &= (color ^ Colors::ALL)
                    end

                    write(Device::REPORT_ID, 0, MAP[color], on ? 1 : 0)
                end
            end

            def get_leds
                @state_seq ||= 1
                begin
                    write(Device::REPORT_ID, 5, 2, @state_seq)
                    Timeout.timeout(0.5) do
                        loop do
                            res = read(6)
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

    end

end

# vim: et sw=4 ts=4