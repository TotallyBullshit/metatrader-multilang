//+------------------------------------------------------------------+
//|                                                       RubyEA.mq4 |
//|                                                            Piotr |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Piotr"
#property link      "http://www.metaquotes.net"

extern int server_port = 8000;
extern bool debug = true;

#include <ruby2.mqh>
int c = 0, s = 0;

int init()
{
   s = r_init(server_port);
   if(debug) Alert(StringConcatenate("port ", server_port, " fd:", s));
   
   return(0);
}

int start()
{
   if(debug) Print(" :: accepting");
   
   while(!IsStopped())
   {
      int ret2 = r_check_accept(s);
      if(debug) Print(" :: r_check_accept() => " + ret2);

      while(!IsStopped())
      {
         c = r_ready_read(s);
         if(c < 1)
            break;
         if(debug) Print(" :: r_ready_read() => " + c);
         
         if(handle_read(c) == -1) {
            if(debug) Alert(" :: start() return");
            return(0);
         }
      }
   }
   return(0);
}

int deinit()
{
//   Alert("closing");
//   make_close_all(s);
   //WSACleanup();
   return(0);
}