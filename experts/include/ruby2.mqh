//#include <stdlib.mqh>
//#include <winsock.mqh>

#import "user32.dll"
   bool GetAsyncKeyState(int Key);
#import "ruby.dll"
   int buf_pos(int& b[], int pos);
   int buf_d_pos(double& buffer[], int pos);
   string buf_pos_s(int& buffer[], int pos);
   int str_pos(string buffer, int pos);
   void buf_copy(int dest, int src, int count);
#import "server.dll"
   int mql_server(int port);
   int r_check_accept(int s);
   int r_ready_read(int c);
   bool r_close(int c);
   //void make_close_all(int s);
   int r_init(int port);
   
   int r_recv_pack(int c);
   int r_packet_return(int c);
   
   int r_int_array(int &arr[]);
   int r_double_array(double &arr[]);
   int r_string_array(string &arr[]);
   
   void r_int_array_set(int &arr[], int size);
   void r_double_array_set(double &arr[], int size);
   void r_string_array_set(string &arr[], int size);
   //string r_str(int i);
#import

#define RVolume         9

#define ROrderClose     100
#define ROrderSend      101
#define ROrderOpenTime  102
#define ROrderCloseTime 103
#define ROrderLots      108
#define ROrderProfit    109
#define ROrderComment   110
#define ROrderMagicNumber 111

#define ROrders         119
#define ROrderSymbol    120
#define ROrderSwap      121
#define ROrderType      124

#define RObjects        200
#define RObjectDelete   201
#define RObjectSet      202
#define RObjectGet      203
#define RObjectDescription 204
#define RObjectSetText  205
#define RObjectType     206
#define RObjectFind     207
#define RObjectCreate   208
#define RObjectMove     209
#define RObjectGetValueByShift 210

#define RWindowRedraw   300
#define RPeriod   301
#define RTimeCurrent   302
#define RSymbol        303

#define RiBars       400
#define RiBarShift   401
#define RiClose      402
#define RiHigh       403
#define RiHighest    404
#define RiLow        405
#define RiLowest     406
#define RiOpen       407
#define RiTime       408
#define RiVolume     409

int msg_int[100];
double msg_dbl[100];
string msg_str[100];

void ret_s(string s)
{
   ArrayResize(msg_int, 0);
   ArrayResize(msg_str, 1);
   ArrayResize(msg_dbl, 0);
   msg_str[0] = s;
}

void ret_d(double d)
{
   ArrayResize(msg_int, 0);
   ArrayResize(msg_str, 0);
   ArrayResize(msg_dbl, 1);
   msg_dbl[0] = d;
}

void ret_i(int i)
{
   ArrayResize(msg_int, 1);
   ArrayResize(msg_str, 0);
   ArrayResize(msg_dbl, 0);
   msg_int[0] = i;
}

void ret_void()
{
   ArrayResize(msg_int, 0);
   ArrayResize(msg_str, 0);
   ArrayResize(msg_dbl, 0);
}

int handle_read(int c) {
         int ret_pack = r_recv_pack(c);
         if(debug) Print(" :: r_recv_pack() => "+ret_pack);
         
         if(ret_pack == 0) {
            ArrayResize(msg_int, 20);
            ArrayResize(msg_dbl, 20);
            ArrayResize(msg_str, 20);
            for(int i=0; i<10; i++)
               msg_str[i] = StringConcatenate("-----------------------------------------------------------", "------------------------------------------------------------");
            if(debug) Print(" :: msg_int "+ArraySize(msg_int));
            
            int msg_ints = r_int_array(msg_int);
            int msg_dbls = r_double_array(msg_dbl);
            int msg_strs = r_string_array(msg_str);
            
            if(debug) Print(StringConcatenate(" :: msg ", msg_strs, " strings, ", msg_ints, " ints, ", msg_dbls, " doubles"));
            if(debug) Print(" :: received msg >>"+msg_int[0]+"<<");
            
            if(msg_int[0] == -1)
               return(-1);
            
            handle_request(msg_int, msg_dbl, msg_str);
            
            if(debug) Print(StringConcatenate(" :: handle ints:", ArraySize(msg_int), " doubles:", ArraySize(msg_dbl), " strings:", ArraySize(msg_str)));
            
            r_int_array_set(msg_int, ArraySize(msg_int));
            r_double_array_set(msg_dbl, ArraySize(msg_dbl));
            r_string_array_set(msg_str, ArraySize(msg_str));
            
            int ret_send = r_packet_return(c);
            if(debug) Print(" :: ret_send => "+ret_send);
         }
         else {
            r_close(c);
            if(debug) Print(" :: closed");
         }
   return(0);
}

void handle_request(int &ints[], double &doubles[], string &strings[]) {
   //Ask, Bid, Point, Bars, Digits, Open, Close, High, Low, Volume, Time
   
   int i;
   
   switch(ints[0]) {
      case -1:
         Alert("return");
         ret_void();
         break;
      
      case 0:
         ret_d(Ask);
         break;
      case 1:
         ret_d(Bid);
         break;
      case 2:
         ret_d(Point);
         break;
      case 3:
         ret_i(Bars);
         break;
      case 4:
         ret_i(Digits);
         break;
      case 5:
         ret_i(Open[ints[1]]);
         break;
      case 6:
         ret_i(Close[ints[1]]);
         break;
      case 7:
         ret_d(High[ints[1]]);
         break;
      case 8:
         ret_d(Low[ints[1]]);
         break;
      case RVolume:
         ret_d(Volume[ints[1]]);
         break;
      case 10:
         ret_i(Time[ints[1]]);
         break;
      
      case ROrderClose:
         ret_i(OrderClose(ints[1], doubles[0], doubles[1], ints[2], ints[3]));
         break;
      case ROrderSend:
         ret_i(OrderSend(strings[0], ints[1], doubles[0], doubles[1], ints[2], doubles[2], doubles[3], strings[1], ints[3], ints[4], ints[5]));
         break;
      case ROrderOpenTime:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_i(OrderOpenTime());
         break;
      case ROrderCloseTime:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_i(OrderCloseTime());
         break;
      case ROrderProfit:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_d(OrderProfit());
         break;
      case ROrderComment:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_s(OrderComment());
         break;
      case ROrderLots:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_d(OrderLots());
         break;
      case ROrderMagicNumber:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_i(OrderMagicNumber());
         break;
      case ROrders:
         int orders = OrdersTotal();
         ArrayResize(ints, orders);
         ArrayResize(strings, 0);
         ArrayResize(doubles, 0);
         
         for(i=0; i<orders; i++) {
            OrderSelect(i, SELECT_BY_POS);
            ints[i] = OrderTicket();
         }
         break;
      case ROrderSymbol:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_s(OrderSymbol());
         break;
      case ROrderSwap:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_d(OrderSwap());
         break;
      case ROrderType:
         OrderSelect(ints[1], SELECT_BY_TICKET);
         ret_i(OrderType());
         break;
      
      case RObjects:
         int objects = ObjectsTotal();
         ArrayResize(ints, 0);
         ArrayResize(strings, objects);
         ArrayResize(doubles, 0);
         
         for(i=0; i<objects; i++)
            strings[i] = ObjectName(i);
         break;
      case RObjectDelete:
         ret_i(ObjectDelete(strings[0]));
         break;
      case RObjectSet:
         ret_i(ObjectSet(strings[0], ints[1], doubles[0]));
         break;
      case RObjectGet:
         ret_d(ObjectGet(strings[0], ints[1]));
         break;
      case RObjectDescription:
         ret_s(ObjectDescription(strings[0]));
         break;
      case RObjectSetText:
         //if(ArraySize(strings) == 3)
            ret_i(ObjectSetText(strings[0], strings[1], ints[1], strings[2], ints[2]));
         //else
         //   ret_i(ObjectSetText(strings[0], strings[1], ints[1], NULL, ints[2]));
         break;
      case RObjectType:
         ret_i(ObjectType(strings[0]));
         break;
      case RObjectFind:
         ret_i(ObjectFind(strings[0]));
         break;
      case RObjectCreate:
         ret_i(ObjectCreate(strings[0], ints[1], ints[2], ints[3], doubles[0], ints[4], doubles[1], ints[5], doubles[2]));
         break;
      case RObjectMove:
         ret_i(ObjectMove(strings[0], ints[1], ints[2], doubles[0]));
         break;
      case RObjectGetValueByShift:
         ret_d(ObjectGetValueByShift(strings[0], ints[1]));
         break;
      
      case RWindowRedraw:
         WindowRedraw();
         ret_void();
         break;
      case RPeriod:
         ret_i(Period());
         break;
      case RTimeCurrent:
         ret_i(TimeCurrent());
         break;
      case RSymbol:
         ret_s(Symbol());
         break;
      
      case RiBars:
         ret_i(iBars(strings[0], ints[1]));
         break;
      case RiBarShift:
         ret_i(iBarShift(strings[0], ints[1], ints[2], ints[3]));
         break;
      case RiClose:
         ret_d(iClose(strings[0], ints[1], ints[2]));
         break;
      case RiHigh:
         ret_d(iHigh(strings[0], ints[1], ints[2]));
         break;
      case RiHighest:
         ret_i(iHighest(strings[0], ints[1], ints[2], ints[3], ints[4]));
         break;
      case RiLow:
         ret_d(iLow(strings[0], ints[1], ints[2]));
         break;
      case RiLowest:
         ret_i(iLowest(strings[0], ints[1], ints[2], ints[3], ints[4]));
         break;
      case RiOpen:
         ret_d(iOpen(strings[0], ints[1], ints[2]));
         break;
      case RiTime:
         ret_i(iTime(strings[0], ints[1], ints[2]));
         break;
      case RiVolume:
         ret_d(iVolume(strings[0], ints[1], ints[2]));
         break;
      
      default:
         Alert(" :: UNKNOWN COMMAND "+ints[0]);
   }
}