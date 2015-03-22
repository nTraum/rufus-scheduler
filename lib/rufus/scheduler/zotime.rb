#--
# Copyright (c) 2006-2015, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++


class Rufus::Scheduler

  #
  # Zon{ing|ed}Time, whatever.
  #
  class ZoTime

    attr_accessor :seconds
    attr_accessor :zone

    def initialize(s, zone)

      @seconds = s.to_f
      @zone = zone
    end

    def time

      in_zone do

        t = Time.at(@seconds)

        if t.isdst
          t1 = Time.at(@seconds + 3600)
          t = t1 if t.zone != t1.zone && t.hour == t1.hour && t.min == t1.min
            # ambiguous TZ (getting out of DST)
        else
          t.hour # force t to compute itself
        end

        t
      end
    end

    def utc

      time.utc
    end

    def add(s)

      @seconds += s.to_f
    end

    def substract(s)

      @seconds -= s.to_f
    end

    def to_f

      @seconds
    end

    def self.parse(str, opts={})

      if defined?(::Chronic) && t = ::Chronic.parse(str, opts)
        return ZoTime.new(t, ENV['TZ'])
      end

      begin
        DateTime.parse(str)
      rescue
        raise ArgumentError, "no time information in #{o.inspect}"
      end if RUBY_VERSION < '1.9.0'

      zone = nil

      s =
        str.gsub(/\S+/) { |m|
          if looks_like_a_timezone?(m)
            zone ||= m
            ''
          else
            m
          end
        }

      return nil unless zone.nil? || is_timezone?(zone)

      zt = ZoTime.new(0, zone || ENV['TZ'])
      zt.in_zone { zt.seconds = Time.parse(s).to_f }

      zt.seconds == nil ? nil : zt
    end

    #FLLATZ_REX = Regexp.new(
    #  "^(" +
    #    "Z(ulu)?" + "|" +
    #    "[A-Z]{3,4}" + "|" +
    #    "[A-Za-z]+\/[A-Za-z_]+" + "|" +
    #    "[+-][0-1][0-9]:?[0-5][0-9]" +
    #  ")$")
    LLATZ_REX = Regexp.new(
      "^(" +
        "(SystemV/)?[A-Z]{3,4}([0-9][A-Z]{3})?" + "|" +
        "([A-Za-z_]+\/){0,2}[A-Za-z_-]+[0-9]*" + "|" +
        "(Etc/)?GMT([+-][0-9]{1,2})?" + "|" +
        "[+-][0-1][0-9]:?[0-5][0-9]" +
      ")$")

    def self.looks_like_a_timezone?(str)

      !! LLATZ_REX.match(str)
    end

    def self.is_timezone?(str)

      return false if str == nil

      return true if Time.zone_offset(str)
      return true if str == 'Zulu'

      return !! (::TZInfo::Timezone.get(str) rescue nil) if defined?(::TZInfo)

      zt = ZoTime.new(0, str)
      t = zt.time

      return false if t.zone == ''
      return false if t.zone == 'UTC' && str != 'UTC'
      return false if str.start_with?(t.zone)

      return false if jruby? && ! LLATZ_REX.match(str)

      true
    end

    def in_zone(&block)

      ptz = ENV['TZ']
      ENV['TZ'] = @zone

      block.call

    ensure

      ENV['TZ'] = ptz
    end
  end
end

