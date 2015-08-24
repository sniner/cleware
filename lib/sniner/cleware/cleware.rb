# encoding: utf-8
#
# cleware.rb - Access library for Cleware devices
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    16.07.2015
# Version::  0.1
#
# == Note
#
# In order to grant users access to Cleware devices you have to give
# them write access on the corresponding device files '/dev/usb/hiddev*`.
# This can be accomplished by e.g. `/etc/udev/rules.d/99-cleware.rules`
# and content:
#
#     ATTRS{idVendor}=="0d50", MODE="0666"
#

require 'timeout'
require_relative 'hidapi'

module Sniner

    module Cleware

        # Cleware device and product IDs
        VENDOR_CLEWARE  = 0x0d50
        PRODUCTS = [
            PRODUCT_LED     = 0x0008,
            PRODUCT_CONTACT = 0x0030,
        ]

        class Error < StandardError
        end

        # Globale Liste aller erkannten USB-Geräte
        @@devices = nil

        def self.devices(filter={})
            @@devices ||= Devices.search_devices
            if filter.empty?
                @@devices
            else
                filter.select! {|k,v| [:name, :product, :vendor, :id].include? k}
                @@devices.select {|dev| filter.find {|k,v| dev.send(k) != v}.nil?}
            end
        end

        module Devices
            REPORT_ID = 0x00

            def self.search_devices
                devmap = Devices.constants.map do |c|
                    o = Devices.const_get(c)
                    if Class === o && o.const_get(:SUPPORTED_PRODUCTS)
                        o.const_get(:SUPPORTED_PRODUCTS).map {|prod| [prod, o]}
                    end
                end.compact.flatten(1).to_h

                HIDAPI.devices(VENDOR_CLEWARE).map do |dev|
                    cls = devmap[dev.idProduct]
                    cls ? cls.new(dev) : nil
                end.compact
            end

            # Base class for all Cleware HID devices
            class Device
                attr_reader :handle, :devinfo

                SUPPORTED_PRODUCTS = []

                def initialize(devinfo)
                    @devinfo = devinfo
                end

                def open
                    @devinfo.open
                    return nil if @devinfo.closed?

                    if block_given?
                        begin
                            yield self
                        ensure
                            close
                        end
                    end

                    self
                end

                def close
                    if @devinfo.open?
                        @devinfo.close
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

                def id
                    @devinfo.id
                end

                def read(len, timeout=1000)
                    return unless @devinfo.open?
                    @@read_seq ||= 1
                    # FIXME: is it necessary or not? Read does work without prior write
                    if @devinfo.write(REPORT_ID, @@read_seq, 0x81)
                        @devinfo.read(len, timeout)
                    end
                ensure
                    @@read_seq = (@@read_seq + 1) & 0xff
                end

                def write(*data)
                    @devinfo.write(*data) if @devinfo.open?
                end

                def to_s
                    @devinfo.to_s
                end
            end

            class TrafficLight < Device
                attr_reader :impl

                SUPPORTED_PRODUCTS = [PRODUCT_LED]

                module Colors
                    RED     = 0x01
                    YELLOW  = 0x02
                    GREEN   = 0x04
                    NONE    = 0x00
                    ALL     = 0x07
                end

                def initialize(devinfo)
                    super
                    @impl = devinfo.version<100 ? OldTL.new(self) : NewTL.new(self)
                end

                def close
                    set(0)
                    super
                end

                # Controller-dependent stuff
                class Impl
                    attr_reader :internal_state

                    MAP = {
                        TrafficLight::Colors::RED => 0x10,
                        TrafficLight::Colors::YELLOW => 0x11,
                        TrafficLight::Colors::GREEN => 0x12
                    }

                    attr_reader :dev

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
                            dev.write(REPORT_ID, 0, MAP[color], on ? 1 : 0)
                        end
                    end

                    def state
                        @internal_state
                    end
                end

                # Traffic light with new controller (version >= 106)
                class NewTL < Impl
                    def state
                        @state_seq ||= 1
                        begin
                            dev.write(REPORT_ID, 5, 2, @state_seq)
                            Timeout.timeout(0.5) do
                                loop do
                                    res = dev.devinfo.read(6, 1000)
                                    # FIXME: Or 'res = dev.read(6)'?
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
                class OldTL < Impl
                    # TODO: dead slow and unreliable
                    def read_state
                        sleep(1) # !!!
                        3.times { dev.read(6) }
                        res = dev.read(6)
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
                        impl.switch(c, (colors&c)!=0)
                    end
                end

                alias :set :leds=

                def red=(state)
                    impl.switch(RED, state)
                end

                def yellow=(state)
                    impl.switch(YELLOW, state)
                end

                def green=(state)
                    impl.switch(GREEN, state)
                end

                def leds
                    impl.state || 0
                end

                alias :get :leds

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

            # Device 'CONTACT v3'
            class Switch < Device
                SUPPORTED_PRODUCTS  = [PRODUCT_CONTACT]

                def read_state
                    10.times do
                        res = read(6)
                        return res[0] & 0x7f if res && (res[0] & 0x80) != 0
                    end
                    nil
                end

                def state
                    (read_state || 0) & 1
                end

                private :read_state
            end
        end

    end

end

# vim: et sw=4 ts=4