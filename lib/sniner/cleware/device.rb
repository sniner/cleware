# encoding: utf-8
#
# device.rb - Base classes of Cleware devices
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    27.10.2015
# Version::  0.2
#

require 'timeout'
require_relative 'hidapi'

# Cleware vendor and product IDs
require_relative 'products'

module Sniner

    module Cleware

        class Device
            attr_reader :devinfo, :conn

            REPORT_ID = 0x00

            def initialize(devinfo, devconn)
                @devinfo = devinfo
                @devconn = devconn
                @conn = nil
            end

            def open
                @devinfo.open unless @devinfo.open?
                return if @devinfo.closed?

                @conn ||= @devconn.send(:new, self)

                if block_given?
                    begin
                        yield @conn
                    ensure
                        close
                    end
                else
                    @conn
                end
            end

            def close
                if @devinfo.open?
                    @devinfo.close
                end
                @conn = nil
            end

            def on_change(initial_value = -1, &block)
                Thread.new(initial_value, block) do |val, action|
                    l = lambda do |conn|
                            while @devinfo.open? do
                                cur_val = conn.state
                                if cur_val != val
                                    action.call(cur_val, self)
                                    val = cur_val
                                end
                                sleep(0.1)
                            end
                        end
                    if @conn
                        l.call(@conn)
                    else
                        open {|conn| l.call(conn)}
                    end
                end
            end

            def name
                @devinfo.product
            end

            def product
                @devinfo.idProduct
            end

            def vendor
                @devinfo.idVendor
            end

            def manufacturer
                @devinfo.manufacturer
            end

            def serial_number
                @devinfo.serialNumber
            end

            def version
                @devinfo.version
            end

            def id
                @devinfo.id
            end

            def path
                @devinfo.path
            end
        end

        class DeviceConnection
            attr_reader :device

            SUPPORTED_PRODUCTS = []

            def initialize(device)
                @device = device
                @hid = @device.devinfo
            end

            def close
                @device.close
            end

            def read(len, timeout=1000)
                return unless @hid.open?
                @@read_seq ||= 1
                # FIXME: is it necessary or not? Read does work without prior write
                if @hid.write(Device::REPORT_ID, @@read_seq, 0x81)
                    @hid.read(len, timeout)
                end
            ensure
                @@read_seq = (@@read_seq + 1) & 0xff
            end

            def write(*data)
                @hid.write(*data) if @hid.open?
            end

            def to_s
                @hid.to_s
            end
        end

    end

end

# vim: et sw=4 ts=4