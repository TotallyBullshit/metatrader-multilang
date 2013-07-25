require 'socket'
require 'msgpack'

class Mql
   OrderComment = 110
   EMPTY = -1
   
   RAsk, RBid, RPoint, RBars, RDigits, ROpen, RClose, RHigh, RLow, RVolume, RTime = *(0..10)
   RObjects, RObjectDelete, RObjectSet, RObjectGet, RObjectDescription, RObjectSetText, RObjectType, RObjectFind, RObjectCreate, RObjectMove, RObjectGetValueByShift = *(200..220)
   RSymbol = 303
   RiBars, RiBarShift, RiClose, RiHigh, RiHighest, RiLow, RiLowest, RiOpen, RiTime, RiVolume = *(400..409)
   
   class Order
      Types = [:buy, :sell, :buylimit, :buystop, :selllimit, :sellstop]
      BUY, SELL = *(0..1)

      def initialize s, ticket
         @s, @ticket = s, ticket
      end

      def lots
         @s.send(108, @ticket).first
      end

      def profit
         @s.send(109, @ticket).first
      end

      def comment
         @s.send(OrderComment, @ticket).first
      end

      def magic_number
         @s.send(111, @ticket).first
      end

      def symbol
         @s.send(120, @ticket).first
      end

      def swap
         @s.send(121, @ticket).first
      end

      def type
         Types[@s.send(124, @ticket).first]
      end

      def open_time
         Time.at @s.send(102, @ticket).first
      end

      def close_time
         Time.at @s.send(103, @ticket).first
      end

      def close slippage=12, color=Color::NONE
         @s.send(100, @ticket, lots, (type == :buy ? @s.bid : @s.ask), slippage, color).first
      end
   end
   
   class Object
      Types = [:vline, :hline, :trend, :trend_by_angle]
      VLine, HLine, Trend, TrendByAngle, Regression, Channel, StdDevChannel, GannLine, GannFan, GannGrid,
      Fibo, FiboTimes, FiboFan, FiboArc, Expansion, FiboChannel, Rectangle, Triangle, Ellipse, Pitchfork,
      Cycles, Text, Arrow, Label = *(0..23)
      PROP_TIME1, PROP_PRICE1, PROP_TIME2, PROP_PRICE2, PROP_TIME3, PROP_PRICE3, PROP_COLOR, PROP_STYLE, PROP_WIDTH, PROP_BACK,
      PROP_RAY, PROP_ELLIPSE, PROP_SCALE, PROP_ANGLE, PROP_ARROWCODE, PROP_TIMEFRAMES, PROP_DEVIATION = *(0..16)
      PROP_FONTSIZE, PROP_CORNER, PROP_XDIST, PROP_YDIST = *(100..103)
      
      attr_reader :name
      
      def initialize s, name
         @s, @name = s, name
      end
      
      def send id, *a
         @s.send(id, @name, *a).first
      end
      
      def delete
         @s.send(201, @name).first
      end
      
      def set(i, val)
         @s.send(RObjectSet, @name, i.to_i, val.to_f).first
      end
      
      def get(i)
         send RObjectGet, i
      end
      
      def color
         get(PROP_COLOR).to_i
      end
      
      def color=(c)
         set PROP_COLOR, c
      end
      
      def style
         get(PROP_STYLE).to_i
      end
      
      def style=(c)
         set PROP_STYLE, c
      end
      
      def corner
         get(PROP_CORNER).to_i
      end
      
      def corner=(c)
         set PROP_CORNER, c
      end
      
      def x
         get(PROP_XDIST).to_i
      end
      
      def x=(c)
         set PROP_XDIST, c
      end
      
      def y
         get(PROP_YDIST).to_i
      end
      
      def y=(c)
         set PROP_YDIST, c
      end
      
      def back
         get(PROP_BACK).to_i
      end
      
      def back=(c)
         set PROP_BACK, case c
         when Fixnum
            c
         when FalseClass
            0
         when TrueClass
            1
         else
            raise ArgumentError.new
         end
      end
      
      def ray
         get(PROP_RAY).to_i
      end
      
      def ray=(c)
         set PROP_RAY, case c
         when Fixnum
            c
         when FalseClass
            0
         when TrueClass
            1
         else
            raise ArgumentError.new
         end
      end
      
      def description
         send RObjectDescription
      end
      
      def description=(s)
         @s.send(RObjectSetText, @name, s, 12, "Times New Roman", Color::Red).first
      end
      
      def set_text s, size=12, font="Times New Roman", color=Color::NONE
         send RObjectSetText, s, size, font, color
      end
      
      def set_opt opts
         opts.each {|prop, val|
            if [:corner, :x, :y, :color, :style, :ray, :back].include? prop
               self.method(:"#{prop}=").call val
            end
         }
         
         self
      end
      
      def []=(coord_i, point)
         send RObjectMove, coord_i.to_i, point[0].to_i, point[1].to_f
      end
      
      def [](coord_i)
         [Time.at(get(PROP_TIME1 + coord_i*2)), get(PROP_PRICE1 + coord_i*2).to_f]
      end
      
      def move *a
         #self[0] = [time1, price1] if time1 and price1
         #self[1] = [time2, price2] if time2 and price2
         #self[2] = [time3, price3] if time3 and price3
         raise ArgumentError.new if a.size > 6
         a.each_with_index {|coord, i| set PROP_TIME1+i, coord.to_f }
      end
      
      #def text_style size, font=nil, color=Color::NONE
      #  @s.send(205, 
      #end

      def at bar
         send RObjectGetValueByShift, bar.to_i
      end

      def type
         Types[@s.send(206, @name).first]
      end
   end
   
   module Trend
      
   end

   def initialize port=8000
      @s = TCPSocket.new('localhost', port)
   end

   def send *args
      msg = [args.select {|o| Fixnum === o },
         args.select {|o| Float === o },
         args.select {|o| String === o }
      ].to_msgpack

      @s.write [msg.size].pack('S') + msg
      
      len = @s.read(2).unpack('S').first
      if len.zero?
         nil
      else
         data = @s.read(len)
         MessagePack.unpack(data).flatten
      end
   end

   def ask
      send(0).first
   end

   def bid
      send(1).first
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

   def orders
      Array(send(119)).map {|ticket| Order.new self, ticket }
   end

   def objects
      send(200).map {|name| Object.new self, name }
   end

   def redraw
      send 300
   end

   def return
      msg = [[-1], [], []].to_msgpack
      @s.write [msg.size].pack('S') + msg
   end

   def [](name)
      if send(RObjectFind, name).first == -1
         nil
      else
         Object.new self, name
      end
   end

   def period
      @period ||= send(301).first
   end

   def time_current
      Time.at send(302).first
   end

   def create type, name, opts={}
      if obj = self[name]
         obj.set_opt opts
      else
         send(RObjectCreate, name, type, 0, 0, 0)
         Object.new(self, name).set_opt opts
      end
   end
   
   def label *a
      create Object::Label, *a
   end
   
   def rectangle *a
      create Object::Rectangle, *a
   end
   
   def trend *a
      create Object::Trend, *a
   end
   
   def symbol
      send(RSymbol).first
   end
end
