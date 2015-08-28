# encoding: utf-8
#
# contact.rb - Cleware contact device
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    28.08.2015
# Version::  0.1
#

require_relative '../products'

module Sniner

    module Cleware

        # Device 'CONTACT v3'
        class Switch < DeviceConnection
            SUPPORTED_PRODUCTS  = [PRODUCT_CONTACT]

            def state
                (read_state || 0) & 1
            end

        private

            def read_state
                10.times do
                    res = read(6)
                    return res[0] & 0x7f if res && (res[0] & 0x80) != 0
                end
                nil
            end

        end

    end

end

# vim: et sw=4 ts=4