# sniner/cleware

Access library for [Cleware](http://cleware.de) devices. Supported devices:

* Traffic light (0d50:0008)
* IO16 (0d50:0030)

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

include Sniner::Cleware::TrafficLight::Colors

tl = Sniner::Cleware.devices(:product => Sniner::Cleware::PRODUCT_LED).first

tl.open do |dev|
    # Setting colors individually
    dev.red = true
    dev.yellow = true
    sleep(1)

    # Using a bit mask
    dev.leds = RED|GREEN
    sleep(1)

    # Flipping on/off states
    dev.leds ^= ALL
    sleep(1)
end
```

## HID API vs libusb

All Cleware gadgets are USB HID class devices. The USB human interface device (HID) class is an abstraction layer while libusb provides low-level access. As far as I know the HID API is the preferred way of accessing Cleware devices, but accessing via libusb does work too. A libusb version is included, but not used by default. This gem has no dependency on libusb, if you want to use the libusb version you have to install the libusb gem manually and `require 'sniner/cleware/cleware_libusb'`.

## Further reading

* Folkert van Heusden https://github.com/flok99/clewarecontrol