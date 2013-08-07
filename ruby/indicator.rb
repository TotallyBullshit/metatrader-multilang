class Mql
   RIndicator = 500

   class Indicator
      IBuffer = 501
      IStyle = 502
      ICopyBuffer = 503

      attr_reader :period, :symbol

      def initialize s, id, p, sym
         @s, @id, @period, @symbol = s, id, p, sym
      end

      def buffer_index(buf)
         @s.remote_call(IBuffer, @id, buf.to_i)
      end

      def style buf_n, type, style=EMPTY, width=EMPTY, clr=-1
         @s.remote_call(IStyle, @id, buf_n.to_i, type.to_i, style, width, clr)
      end

      def buffer_copy offset, ary
         @s.remote_call(ICopyBuffer, @id, offset.to_i, *ary.map(&:to_f))
      end
   end

   def indicator str
      if id_arr = send(RIndicator, str)
         p id_arr.each_slice(3).to_a
         id_arr.each_slice(3).map {|args| Indicator.new(self, *args) }
      end
   end
end
