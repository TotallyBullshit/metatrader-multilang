class Mql
   class Order
      Types = [:buy, :sell, :buylimit, :buystop, :selllimit, :sellstop]
      BUY, SELL = *(0..1)

      attr_reader :ticket

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

   def orders
      Array(send(119)).map {|ticket| Order.new self, ticket }
   end
end
