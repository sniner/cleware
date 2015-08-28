# encoding: utf-8
#
# products.rb - USB ID definitions of Cleware devices
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    28.08.2015
# Version::  0.1
#

module Sniner

    module Cleware

        VENDOR_CLEWARE      = 0x0d50

        PRODUCTS = [
            PRODUCT_LED     = 0x0008,
            PRODUCT_CONTACT = 0x0030,
        ]

    end

end

# vim: et sw=4 ts=4