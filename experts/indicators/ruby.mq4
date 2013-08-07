#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1  Blue

extern bool debug = true;
extern string script_name = "import-csv";

#include <ruby2.mqh>

double ind_buf[];
int s = 0;

int init()
{
   s = ind_init(script_name, Symbol(), Period());

   SetIndexBuffer(0, ind_buf);

   return(0);
}

void handle_indicator_procedure(int msg)
{
   int offset, i;

   switch(msg) {
      case 501:
         SetIndexBuffer(msg_int[2], ind_buf);
         break;

      case 502:
         SetIndexStyle(msg_int[2], msg_int[3], msg_int[4], msg_int[5], msg_int[6]);
         break;

      case 503:
         offset = msg_int[2];

         for(i=0; i<ArraySize(msg_dbl); i++)
            ind_buf[i+offset] = msg_dbl[i];
         break;
   }
}

int start()
{
   copy_arrays(s);

   if(ArraySize(msg_int) > 2) {
      handle_indicator_procedure(msg_int[0]);
   }

   return(0);
}

int deinit()
{
   ind_finish(s);
   return(0);
}
