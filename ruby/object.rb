class Mql
   RObjects,
   RObjectDelete,
   RObjectSet,
   RObjectGet,
   RObjectDescription,
   RObjectSetText,
   RObjectType,
   RObjectFind,
   RObjectCreate,
   RObjectMove,
   RObjectGetValueByShift = *(200..220)

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
            if respond_to?(sym = :"#{prop}=")
               self.method(sym).call(val)
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

      def at bar
         send RObjectGetValueByShift, bar.to_i
      end

      def type
         Types[@s.send(206, @name).first]
      end
   end

   def objects
      send(200).map {|name| Object.new self, name }
   end

   def [](name)
      if send(RObjectFind, name).first == -1
         nil
      else
         Object.new self, name
      end
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
end
