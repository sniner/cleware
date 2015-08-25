# sniner/cleware

Access library for [Cleware](http://cleware.de) devices. Only the traffic light is supported right now.

## Dependencies

* HIDAPI: Be sure to install the right hidapi library. It comes in two flavors: based on libusb and one called 'raw'. Get hidapi based on libusb if you have to choose one. On Arch Linux you will find one package with both flavors included.
* libc: Needed for converting wide-strings.
* FFI gem

## Permissions

In order to grant users access to Cleware devices you have to give them write access on the corresponding device files `/dev/usb/hiddev*`. This can be accomplished by e.g. `/etc/udev/rules.d/99-cleware.rules` with following content:

    ATTRS{idVendor}=="0d50", MODE="0666"

## Building the gem

    gem build cleware.gemspec
    gem install cleware-0.1.0.gem

## Example

```
require 'sniner/cleware'

include Sniner::Cleware::Devices::TrafficLight::Colors

tl = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_LED).first

tl.open do
    # Setting colors individually
    tl.red = true
    tl.yellow = true
    sleep(1)

    # Using a bit mask
    tl.leds = RED|GREEN
    sleep(1)

    # Flipping on/off states
    tl.leds ^= ALL
    sleep(1)
end
```