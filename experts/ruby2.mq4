#property copyright "Piotr"
#property link      "https://github.com/pczarn/metatrader-multilang"

extern int server_port = 8000;
extern int port_limit = 8100;
extern bool debug = true;

#include <ruby2.mqh>

int s = 0;

int init()
{
   s = r_init(server_port);
   int port = server_port;

   if(s == -1) {
      // in case of failure
      if(debug)
         Alert(" :: port ", server_port, " is in use!");

      while(s == -1 && port < port_limit) {
         port += 1;
         s = r_init(port, script_name);
      }
   }

   if(debug)
      Print(" :: using port ", port);
   
   return(0);
}

int start()
{
   while(!IsStopped())
   {
      int ret2 = r_check_accept(s);

      while(!IsStopped())
      {
         int c = r_ready_read(s);

         if(c < 1)
            break;
         if(debug) Print(" :: r_ready_read() => " + c);

         if(handle_incoming(c) == -1) {
            if(debug) Alert(" :: start() return");
            return(0);
         }
      }

      if(IsTesting())
         break;
   }
   return(0);
}

int deinit()
{
   r_finish(s);
   return(0);
}
