# encoding: utf-8
#
# cleware.rb - Access library for Cleware devices
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    28.08.2015
# Version::  0.2
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

# Cleware vendor and product IDs
require_relative 'products'

module Sniner

    module Cleware

        class Error < StandardError
        end

        # All Cleware devices found
        @@devices = nil

        def self.devices(filter={})
            @@devices ||= search_devices
            if filter.empty?
                @@devices
            else
                filter.select! {|k,v| [:name, :product, :vendor, :id].include? k}
                @@devices.select {|dev| filter.find {|k,v| dev.send(k) != v}.nil?}
            end
        end

        require_relative 'device'
        require_relative 'devices/trafficlight'
        require_relative 'devices/contact'

    private

        def self.search_devices
            devmap = Cleware.constants.map do |c|
                o = Cleware.const_get(c)
                if Class === o && o.const_defined?(:SUPPORTED_PRODUCTS)
                    o.const_get(:SUPPORTED_PRODUCTS).map {|prod| [prod, o]}
                end
            end.compact.flatten(1).to_h

            HIDAPI.devices(VENDOR_CLEWARE).map do |dev|
                cls = devmap[dev.idProduct]
                cls ? Device.new(dev, cls) : nil
            end.compact
        end

    end

end

# vim: et sw=4 ts=4