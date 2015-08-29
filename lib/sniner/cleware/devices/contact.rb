# encoding: utf-8
#
# contact.rb - Cleware 'IO16' device
#
# Author::  Stefan Schönberger (mailto:mail@sniner.net)
# Date::    29.08.2015
# Version:: 0.2.0
#

require 'timeout'
require_relative '../products'

module Sniner

    module Cleware

        class Contact < DeviceConnection
            SUPPORTED_PRODUCTS  = [PRODUCT_CONTACT]

            # Sets the direction of the lines of the USB-IO16 lines.
            # 'mask' must be an integer value, 16 bits represent the
            # 16 i/o lines of an IO16 device. Bit 0 is line 1, bit 15
            # is line 16. A set bit means output, a cleared bit means input.
            #
            # Examples:
            #    dev.directions = 0xffff # All lines are inputs
            #    dev.directions = 0 # All lines are output
            #    dev.directions = 7 # Lines 1-3 are input, 4-16 output
            def directions=(mask)
                b0 = 0x70 | ((mask & 0x8000)!=0 ? 8 : 0) | ((mask & 0x0080)!=0 ? 4 : 0)
                b1 = (mask >> 8) & 0x7f
                b2 = mask & 0x7f
                write(Device::REPORT_ID, b0, b1, b2, 0, 0)
                sleep(0.1)
            end

            # Set output lines to on or off. 'mask' must be an integer value,
            # 16 bits represent the 16 i/o lines of an IO16 device. Bit 0 is
            # line 1, bit 15 is line 16. A set bit means 'on', a cleared bit
            # means 'off'.
            def state=(mask)
                b0 = 0x33 | ((mask & 0x8000)!=0 ? 8 : 0) | ((mask & 0x0080)!=0 ? 4 : 0)
                b1 = (mask >> 8) & 0x7f
                b2 = mask & 0x7f
                write(Device::REPORT_ID, b0, b1, b2, 0x7f, 0x7f)
            end

            # Read the state of the I/O lines. Returns an integer, bit 0
            # represents state of line 1, bit 15 represents line 16. A set
            # bit means 'on' (output line) or 'short' (input line), a cleared bit
            # means 'off' (output line) or 'open' (input line).
            def state
                mask = 0xffff # read all bits
                begin
                    Timeout.timeout(0.5) do
                        loop do
                            seq = sync(mask)
                            sleep(0.02)
                            5.times do
                                res = read(6)
                                if res && res.length >= 6
                                    if res[1] == seq
                                        #mask = (res[2]<<8) + res[3]
                                        return (res[4]<<8) + res[5]
                                    end
                                end
                            end
                        end
                    end
                rescue Timeout::Error
                    nil
                end
            end

        private

            def sync(mask=0)
                @seq ||= 1
                mask = 0xffff if mask == 0
                b0 = 0x60 | ((mask & 0x8000)!=0 ? 2 : 0) | ((mask & 0x0080)!=0 ? 1 : 0)
                b3 = (mask >> 8) & 0x7f
                b4 = mask & 0x7f
                write(Device::REPORT_ID, b0, @seq, 0, b3, b4) ? @seq : 0
            ensure
                @seq = (@seq + 1) & 0x7f
                @seq = 1 if @seq == 0
            end

        end

    end

end

# vim: et sw=4 ts=4