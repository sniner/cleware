# encoding: utf-8
#
# contact.rb - Cleware 'IO16' device
#
# Author::  Stefan Schönberger (mailto:mail@sniner.net)
# Date::    31.08.2015
# Version:: 0.2.2
#

require 'timeout'
require_relative '../products'

module Sniner

    module Cleware

        class Contact < DeviceConnection
            SUPPORTED_PRODUCTS  = [PRODUCT_CONTACT]

            # Sets the direction of the USB-IO16 lines. The bitmask
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

            # Get the direction bitmask (see #directions=).
            def directions
                state[1]
            end

            # Set output lines to on or off. 'data' must be an integer value,
            # 16 bits represent the 16 i/o lines of an IO16 device. Bit 0 is
            # line 1, bit 15 is line 16. A set bit means 'on', a cleared bit
            # means 'off'.
            def lines=(data)
                set_lines(data)
            end

            # Get state of output lines as bitmask.
            def lines(mask = 0xffff)
                state(mask)[0]
            end

            # Set one line on or off.
            # line: 0..15
            # on: true or false
            def []=(line, on)
                mask = 1 << (line&0x0f)
                set_lines(on ? mask : 0, mask)
            end

            # Get state of one line.
            # line: 0..15
            # Return value is true or false.
            def [](line)
                mask = 1 << (line&0x0f)
                (lines & mask) != 0
            end

            # Number of lines
            def count
                state(0xffff)[2]
            end

            # Read the state of the I/O lines. Returns an array of three integers:
            #
            #   * first integer is a line bitmap: bit 0 represents state
            #     of line 1, bit 15 represents line 16. A set bit means 'on'
            #     (output line) or 'short' (input line), a cleared bit means 'off'
            #     (output line) or 'open' (input line).
            #   * second integer is the direction bitmask (see #directions=).
            #   * third integer contains the number of lines (or zero if unsupported).
            #
            # The returned array will be empty on timeout condition.
            def state(mask = 0xffff)
                if device.version<10
                    get_state0(mask)
                else
                    get_state1(mask)
                end
            end

        private

            def sync(mask = 0xffff)
                @seq ||= 1
                b0 = 0x60 | ((mask & 0x8000)!=0 ? 2 : 0) | ((mask & 0x0080)!=0 ? 1 : 0)
                b3 = (mask >> 8) & 0x7f
                b4 = mask & 0x7f
                write(Device::REPORT_ID, b0, @seq, 0, b3, b4) ? @seq : 0
            ensure
                @seq = (@seq + 1) & 0x7f
                @seq = 1 if @seq == 0
            end

            def set_lines(data, mask=0xffff)
                return false if device.version <= 6
                b0 = 0x30 |
                        ((data & 0x8000)!=0 ? 8 : 0) |
                        ((data & 0x0080)!=0 ? 4 : 0) |
                        ((mask & 0x8000)!=0 ? 2 : 0) |
                        ((mask & 0x0080)!=0 ? 1 : 0)
                b1 = (data >> 8) & 0x7f
                b2 = data & 0x7f
                b3 = (mask >> 8) & 0x7f
                b4 = mask & 0x7f
                write(Device::REPORT_ID, b0, b1, b2, b3, b4)
            end

            # Contact v3
            def get_state0(mask = 0xffff)
                10.times do
                    res = read(6)
                    if res && (res[0] & 0x80) != 0
                        return res[0] & 0x7f, 1, 1
                    end
                end
                []
            end

            # IO16 v14
            def get_state1(mask = 0xffff)
                begin
                    Timeout.timeout(0.5) do
                        loop do
                            seq = sync(mask)
                            sleep(0.02)
                            5.times do
                                res = read(6)
                                if res && res.length >= 6
                                    if res[1] == seq
                                        conf = res[0] & 0x7f
                                        dir = (res[2]<<8) + res[3]
                                        lines = (res[4]<<8) + res[5]
                                        return lines & mask, dir, conf
                                    end
                                end
                            end
                        end
                    end
                rescue Timeout::Error
                    []
                end
            end

        end

    end

end

# vim: et sw=4 ts=4