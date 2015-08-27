# encoding: utf-8
#
# cleware-libusb.rb - Access library for Cleware devices (libusb version)
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    27.08.2015
# Version::  0.1
#
# == Note 1
#
# This implementation does not use HID API but low-level libusb instead.
# It works as expected, but as far as I know accessing the Cleware
# devices through HID API is preferred, so this is enclosed for the sake
# of completeness.
#
# == Note 2
#
# In order to grant users access to Cleware devices you have to give
# them write access on the corresponding device files '/dev/usb/hiddev*`.
# This can be accomplished by e.g. `/etc/udev/rules.d/99-cleware.rules`
# and content:
#
#     ATTRS{idVendor}=="0d50", MODE="0666"
#

require 'timeout'
require 'libusb'

module Sniner

    module Cleware

        # Cleware vendor and product IDs
        VENDOR_CLEWARE  = 0x0d50
        PRODUCTS = [
            PRODUCT_LED     = 0x0008,
            PRODUCT_CONTACT = 0x0030,
        ]

        class Error < StandardError
        end

        # All Cleware devices found
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
            def self.search_devices
                devmap = Devices.constants.map do |c|
                    o = Devices.const_get(c)
                    if Class === o && o.const_get(:SUPPORTED_PRODUCTS)
                        o.const_get(:SUPPORTED_PRODUCTS).map {|prod| [prod, o]}
                    end
                end.compact.flatten(1).to_h

                usb = LIBUSB::Context.new
                @devices = usb.devices(:idVendor => VENDOR_CLEWARE).map do |dev|
                    cls = devmap[dev.idProduct]
                    cls ? cls.new(dev) : nil
                end.compact
            end

            # Base class for all Cleware HID devices
            class Device
                attr_reader :handle, :device, :endpoints_in, :endpoints_out

                SUPPORTED_PRODUCTS = []

                def initialize(device)
                    @device = device
                end

                def open
                    @endpoints_in = @device.endpoints.select{|ep| ep.bEndpointAddress&LIBUSB::ENDPOINT_IN != 0}
                    @endpoints_out = @device.endpoints.select{|ep| ep.bEndpointAddress&LIBUSB::ENDPOINT_IN == 0}

                    @handle = @device.open
                    if LIBUSB.has_capability? LIBUSB::CAP_SUPPORTS_DETACH_KERNEL_DRIVER
                        @handle.detach_kernel_driver(0) if @handle.kernel_driver_active?(0)
                    end
                    @handle.claim_interface(0)

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
                    if @handle
                        @handle.release_interface(0)
                        if LIBUSB.has_capability? LIBUSB::CAP_SUPPORTS_DETACH_KERNEL_DRIVER
                            @handle.attach_kernel_driver(0)
                        end
                        @handle.close
                        @handle = nil
                    end
                end

                def reset
                    return unless @handle
                    begin
                        @handle.reset_device
                    rescue LIBUSB::ERROR_NOT_FOUND
                        @handle.close
                        # FIXME: doesn't work, LIBUSB::ERROR_NOT_FOUND raised
                        open
                    rescue LIBUSB::Error => ex
                        $stderr.puts ex
                        @handle = nil
                    end
                end

                def open?
                    ! @handle.nil?
                end

                def name
                    @device.product
                end

                def product
                    @device.idProduct
                end

                def vendor
                    @device.idVendor
                end

                def manufacturer
                    @device.manufacturer
                end

                def id
                    sprintf("%04x:%04x", @device.idVendor, @device.idProduct)
                end

                def ctrl_read_str(bytes)
                    @handle.control_transfer(
                        :bmRequestType => LIBUSB::ENDPOINT_IN|LIBUSB::REQUEST_TYPE_CLASS|LIBUSB::RECIPIENT_INTERFACE,
                        :bRequest => 0x09,
                        :wValue => 0x00,
                        :wIndex => 0x00,
                        :dataIn => bytes)
                rescue LIBUSB::Error => ex
                    $stderr.puts ex
                    nil
                ensure
                    @handle.clear_halt(ep)
                end

                def ctrl_read(bytes)
                    data = ctrl_read_str(bytes)
                    data.unpack('C*') if data
                end

                def ctrl_write_str(str)
                    len = @handle.control_transfer(
                            :bmRequestType => LIBUSB::ENDPOINT_OUT|LIBUSB::REQUEST_TYPE_CLASS|LIBUSB::RECIPIENT_INTERFACE,
                            :bRequest => 0x09,
                            :wValue => 0x200,
                            :wIndex => 0x00,
                            :dataOut => str.force_encoding('BINARY'))
                    len == str.length
                end

                def ctrl_write(*array)
                    ctrl_write_str(array.pack("c*"))
                end

                def intr_read_str(bytes, timeout=1)
                    ep = @endpoints_in[0]
                    return nil unless ep
                    begin
                        @handle.interrupt_transfer(
                            :endpoint => ep,
                            :dataIn => bytes || ep.wMaxPacketSize,
                            :timeout => timeout*1000)
                    rescue LIBUSB::Error => ex
                        $stderr.puts ex
                        nil
                    ensure
                        @handle.clear_halt(ep)
                    end
                end

                def intr_read(bytes, timeout=1)
                    data = intr_read_str(bytes, timeout)
                    data.unpack('C*') if data
                end

                def intr_write_str(str)
                    ep = @endpoints_out[0]
                    return false unless ep
                    begin
                        len = @handle.interrupt_transfer(
                                :endpoint => ep,
                                :dataOut => str.force_encoding('BINARY'))
                        len == str.length
                    rescue LIBUSB::Error => ex
                        $stderr.puts ex
                        false
                    end
                end

                def intr_write(*array)
                    intr_write_str(array.pack("c*"))
                end

                def to_s
                    "#{name} (#{id}) by #{manufacturer}"
                end
            end

            class TrafficLight < Device
                attr_reader :state

                SUPPORTED_PRODUCTS = [PRODUCT_LED]

                CMD_OFF     = 0x0
                CMD_ON      = 0x1

                module Colors
                    RED     = 0x01
                    YELLOW  = 0x02
                    GREEN   = 0x04
                    NONE    = 0x00
                    ALL     = 0x07

                    MAP = {
                        RED     => 0x10,
                        YELLOW  => 0x11,
                        GREEN   => 0x12
                    }
                end

                def initialize(device)
                    super
                    @state = 0
                end

                def set_led(color, on)
                    if on
                        @state |= color
                    else
                        @state &= (color ^ TrafficLight::ALL)
                    end

                    # The old controller used by Cleware had no output endpoint
                    @write ||= if endpoints_out.empty? then :ctrl_write else :intr_write end
                    send(@write, 0x0, Colors::MAP[color], on ? CMD_ON : CMD_OFF)
                end

                def get_leds
                    @state
                end

                private :set_led, :get_leds

                def leds=(colors)
                    [Colors::RED, Colors::YELLOW, Colors::GREEN].each do |c|
                        set_led(c, (colors&c)!=0)
                    end
                end

                alias :set :leds=

                def red=(state)
                    set_led(Colors::RED, state)
                end

                def yellow=(state)
                    set_led(Colors::YELLOW, state)
                end

                def green=(state)
                    set_led(Colors::GREEN, state)
                end

                def leds
                    get_leds || 0
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
                        res = intr_read(8)
                        return res[0] & 0x7f if res && (res[0] & 0x80) != 0
                    end
                    nil
                end

                def state
                    (read_state || 0) & 1
                end

                def on_change(initial_value = -1, &block)
                    Thread.new(initial_value, block) do |val, action|
                        open do |dev|
                            loop do
                                cur_val = dev.state
                                if cur_val != val
                                    action.call(cur_val, self)
                                    val = cur_val
                                end
                                sleep(0.1)
                            end
                        end
                    end
                end

                private :read_state
            end
        end

    end

end

# vim: et sw=4 ts=4