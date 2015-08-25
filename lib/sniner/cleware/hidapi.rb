# encoding: utf-8
#
# hidapi.rb - Ruby-FFI binding for HIDAPI library
#
# Autor::    Stefan Schönberger (mailto:mail@sniner.net)
# Datum::    15.07.2015
# Version::  1.0
#
# == Notes
#
# Be sure to install the right hidapi library. It comes in two flavors:
# based on libusb and one called 'raw'. Get hidapi based on libusb if
# you have to choose one.
#
#   Debian Jessie: libhidapi-libusb0
#   Arch Linux: hidapi
#
# == Dependencies
#
#   * FFI gem
#   * hidapi-libusb.so
#   * libc.so

require 'ffi'

module Sniner
    module HIDAPI

        # See: http://www.gnu.org/software/libc/manual/html_node/Converting-Strings.html
        module LIBC
            extend FFI::Library

            ffi_lib 'c'

            attach_function :wcstombs, [:pointer, :pointer, :size_t], :size_t
            attach_function :mbstowcs, [:pointer, :string, :size_t], :size_t
            attach_function :wcslen, [:pointer], :size_t

            def self.wstr_to_str(wstr_ptr)
                return nil if wstr_ptr.address==0
                buf = FFI::MemoryPointer.new(:char, 4*wcslen(wstr_ptr) + 1)
                len = LIBC.wcstombs(buf, wstr_ptr, buf.size)
                buf.get_string(0, len)
            end

            def self.str_to_wstr(str)
                return nil if str.nil?
                buf = FFI::MemoryPointer.new(:uint8, 4*(str.length+1))
                len = LIBC.mbstowcs(buf, str, str.length)
                buf
            end
        end

        module LIBHID
            extend FFI::Library

            ffi_lib 'hidapi-libusb'

            # See: /usr/include/hidapi/hidapi.h
            class HIDDeviceInfo < FFI::Struct
                layout  :path,                  :string,    # Platform-specific device path
                        :vendor_id,             :ushort,    # Device Vendor ID
                        :product_id,            :ushort,    # Device Product ID
                        :serial_number,         :pointer,   # wide string: Serial Number
                        :release_number,        :ushort,    # Device Release Number
                        :manufacturer_string,   :pointer,   # wide string: Manufacturer String
                        :product_string,        :pointer,   # wide string: Product string
                        :usage_page,            :ushort,    # Usage Page (Windows/Mac only)
                        :usage,                 :ushort,    # Usage (Windows/Mac only)
                        :interface_number,      :int,       # USB interface
                        :next,                  :pointer    # HIDDeviceInfo.ptr
            end

            attach_function :hid_init, [], :int
            attach_function :hid_exit, [], :int
            attach_function :hid_enumerate, [:ushort, :ushort], :pointer # HIDDeviceInfo.ptr
            attach_function :hid_free_enumeration, [:pointer], :void
            attach_function :hid_open, [:ushort, :ushort, :pointer], :pointer
            attach_function :hid_open_path, [:string], :pointer
            attach_function :hid_write, [:pointer, :pointer, :size_t], :int
            attach_function :hid_read_timeout, [:pointer, :pointer, :size_t, :int], :int
            attach_function :hid_read, [:pointer, :pointer, :size_t], :int
            attach_function :hid_set_nonblocking, [:pointer, :int], :int
            attach_function :hid_send_feature_report, [:pointer, :pointer, :size_t], :int
            attach_function :hid_get_feature_report, [:pointer, :pointer, :size_t], :int
            attach_function :hid_close, [:pointer], :void
            attach_function :hid_get_manufacturer_string, [:pointer, :pointer, :size_t], :int
            attach_function :hid_get_product_string, [:pointer, :pointer, :size_t], :int
            attach_function :hid_get_serial_number_string, [:pointer, :pointer, :size_t], :int
            attach_function :hid_get_indexed_string, [:pointer, :int, :pointer, :size_t], :int
            attach_function :hid_error, [:pointer], :pointer

            def self.get_string(handle, function, buflen=256)
                buf = FFI::MemoryPointer.new(:uint8, buflen)
                res = LIBHID.send(function, handle, buf, (buflen-1)/4)
                LIBC.wstr_to_str(buf) unless res<0
            end

            def self.get_indexed_string(handle, index, buflen=256)
                buf = FFI::MemoryPointer.new(:uint8, buflen)
                res = LIBHID.hid_get_indexed_string(handle, index, buf, (buflen-1)/4)
                LIBC.wstr_to_str(buf) unless res<0
            end
        end

        class DevInfo
            attr_reader :handle, :path, :idVendor, :idProduct, :serialNumber,
                        :manufacturer, :product, :version

            # info: LIBHID::HIDDeviceInfo
            def initialize(info)
                @idVendor = info[:vendor_id]
                @idProduct = info[:product_id]
                @path = info[:path]
                @serialNumber = LIBC.wstr_to_str(info[:serial_number])
                @product = LIBC.wstr_to_str(info[:product_string])
                @manufacturer = LIBC.wstr_to_str(info[:manufacturer_string])
                @version = info[:release_number]
            end

            def id
                sprintf("%04x:%04x", idVendor, idProduct)
            end

            def open
                @handle = LIBHID.hid_open(idVendor, idProduct, LIBC.str_to_wstr(serialNumber))
                if block_given? && open?
                    begin
                        yield self
                    ensure
                        close
                    end
                else
                    self
                end
            end

            def close
                if open?
                    LIBHID.hid_close(@handle)
                end
                @handle = nil
            end

            def closed?
                @handle.nil? || @handle.address==0
            end

            def open?
                ! closed?
            end

            def product_string
                LIBHID.get_string(@handle, :hid_get_product_string)
            end

            def manufacturer_string
                LIBHID.get_string(@handle, :hid_get_manufacturer_string)
            end

            def serial_number_string
                LIBHID.get_string(@handle, :hid_get_serial_number_string)
            end

            def indexed_string(index)
                LIBHID.get_indexed_string(@handle, index)
            end

            def error
                LIBC.wstr_to_str(LIBHID.hid_error(@handle))
            end

            def nonblocking=(switch)
                LIBHID.hid_set_nonblocking(@handle, switch ? 1 : 0) >= 0
            end

            # Send a string of bytes to device.
            # @return is true, if data has been written, false otherwise
            def write_str(data)
#                $stderr.puts "write: #{data.inspect}"
                buf = FFI::MemoryPointer.new(:uint8, data.size)
                buf.put_bytes(0, data)
                LIBHID.hid_write(@handle, buf, buf.size) == buf.size
            end

            def write(*data)
                write_str(data.flatten.pack('C*'))
            end

            # Read string of bytes from device.
            # timeout: milliseconds to wait at max or nil for blocking
            # @return is nil on timeout
            def read_str(len, timeout=nil)
                buf = FFI::MemoryPointer.new(:uint8, len)
                read = if timeout
                    LIBHID.hid_read_timeout(@handle, buf, buf.size, timeout)
                else
                    LIBHID.hid_read(@handle, buf, buf.size)
                end
                res = if read<0
                    nil
                else
                    buf.get_bytes(0, read)
                end
#                $stderr.puts "read(#{len}): #{res.inspect}"
                res
            end

            def read(len, timeout=nil)
                data = read_str(len, timeout)
                data.unpack('C*') if data
            end

            def write_feature_str(data)
                buf = FFI::MemoryPointer.new(:uint8, data.size)
                buf.put_bytes(0, data)
                LIBHID.hid_send_feature_report(@handle, buf, buf.size) == buf.size
            end

            def write_feature(*data)
                write_feature_str(data.flatten.pack('C*'))
            end

            def read_feature_str(len)
                buf = FFI::MemoryPointer.new(:uint8, len)
                read = LIBHID.hid_get_feature_report(@handle, buf, buf.size)
                buf.read_bytes(read) unless read<0
            end

            def read_feature(len)
                data = read_feature_str(len)
                data.unpack('C*') if data
            end

            def to_s
                [
                    product ? product : nil,
                    manufacturer ? 'by ' + manufacturer : nil,
                    id,
                    serialNumber ? 'SN:'+serialNumber : nil,
                    version!=0 ? 'V:'+version.to_s : nil,
                ].compact.join(' ')
            end
        end

        # Retrieve a list of HIDDeviceInfo objects.
        def self.devices(vendor=0, product=0)
            list = []
            p = ptr = LIBHID.hid_enumerate(vendor, product)
            while ptr.address != 0
                dev = LIBHID::HIDDeviceInfo.new(ptr)
                list << DevInfo.new(dev)
                ptr = dev[:next]
            end
            LIBHID.hid_free_enumeration(p)
            list
        end

    end
end


# vim: et sw=4 ts=4