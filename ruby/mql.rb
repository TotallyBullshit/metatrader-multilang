require 'socket'
require 'msgpack'

require_relative 'order'
require_relative 'object'
require_relative 'indicator'
require_relative 'color'

class MqlClose < StandardError; end

class Mql
   OrderComment = 110
   EMPTY = -1
   
   RAsk, RBid, RPoint, RBars, RDigits, ROpen, RClose, RHigh, RLow, RVolume, RTime = *(0..10)
   RSymbol = 303
   RiBars, RiBarShift, RiClose, RiHigh, RiHighest, RiLow, RiLowest, RiOpen, RiTime, RiVolume = *(400..409)



   def initialize port=8000
      i = 0

      begin
         i += 1
         @s = TCPSocket.new('localhost', port)
      rescue Errno::ECONNREFUSED
         raise if i > 5
         sleep 0.1
         retry

      end
   end

   def send *args
      remote_call *args
      receive
   end

   def remote_call *args
      msg = [
         args.select {|o| Fixnum === o },
         args.select {|o| Float === o },
         args.select {|o| String === o }
      ].to_msgpack

      @s.write([msg.size].pack('S') << msg)
   end

   def receive
      begin
         len = @s.read(2)
      rescue Errno::ECONNRESET
      end
      raise MqlClose.new if len.nil?

      len = len.unpack('S').first
      if len.zero?
         nil
      else
         data = @s.read(len)
         begin
            MessagePack.unpack(data).flatten
         rescue
            binding.pry
         end
      end
   end

   def ask
      send(0).first
   end

   def bid
      send(1).first
   end

   def bar_at_time time_at, opts={}
      send(RiBarShift, opts[:symbol]||symbol, opts[:period]||period, time_at.to_i, (opts[:exact] ? 1 : 0)).first
   end

   def bar_ind id1, id2, bar=0, opts={}
      if opts.empty?
         send(id1, bar.to_i).first
      else
         send(id2, opts[:symbol]||symbol, opts[:period]||period, bar.to_i).first
      end
   end

   def time *a
      Time.at bar_ind 10, RiTime, *a
   end

   def volume *a
      bar_ind RVolume, RiVolume, *a
   end

   def open *a
      bar_ind ROpen, RiOpen, *a
   end

   def close *a
      bar_ind RClose, RiClose, *a
   end

   def high *a
      bar_ind RHigh, RiHigh, *a
   end

   def low *a
      bar_ind RLow, RiLow, *a
   end

   def redraw
      send 300
   end

   def return
      msg = [[-1], [], []].to_msgpack
      @s.write [msg.size].pack('S') + msg
   end

   def period
      @period ||= send(301).first
   end

   def time_current
      Time.at send(302).first
   end
   
   def symbol
      @symbol ||= send(RSymbol).first
   end
end
