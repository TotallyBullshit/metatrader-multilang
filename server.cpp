//C++11: remote procedure call library for MQL4
//g++ server.cpp -o server.dll -s -shared -Wl,--kill-at -std=c++11 -lws2_32

#include "winsock2.h"
#include "time.h"
#include <iostream>
#include <algorithm>
#include <vector>
#include <msgpack.hpp>

using namespace std;

const int kBufferSize = 1024;
vector<SOCKET> gConnections;

vector<int> int_array;
vector<double> double_array;
vector<std::string> string_array;

int type_return, int_return;
double double_return;
char *string_return;

struct Indicator {
    std::string name;

    std::string symbol;
    int period;

    vector<int> ints;
    vector<double> doubles;
    vector<std::string> strings;

    Indicator(std::string n, std::string s, int p)
        : name(n), symbol(s), period(p) {}
};

vector<Indicator*> indicators;

/*
00 GETCONST     ([int]) -> int|double           double Ask, Bid, Point/int Bars, Digits/double Open[], Close[], High[], Low[], Volume[]/int Time[]
01 ACCINFO      -> double                       double AccountBalance()
02 
*/

#define MQLCALL __stdcall
#define MQLAPI __declspec(dllexport)

struct mql_string {
    size_t len;
    char *s;
};

extern "C" {
MQLAPI SOCKET MQLCALL r_init(int port);
MQLAPI bool   MQLCALL r_close(SOCKET sd);
MQLAPI void   MQLCALL r_finish(SOCKET);

MQLAPI SOCKET MQLCALL r_accept(SOCKET);
MQLAPI SOCKET MQLCALL r_check_accept(SOCKET);
MQLAPI SOCKET MQLCALL r_ready_read(SOCKET);

MQLAPI int    MQLCALL r_recv_pack(SOCKET sd);
MQLAPI int    MQLCALL r_packet_return(SOCKET);

MQLAPI void   MQLCALL r_array_size(int*, Indicator*);
MQLAPI int    MQLCALL r_int_array(int*, Indicator*);
MQLAPI int    MQLCALL r_double_array(double*, Indicator*);
MQLAPI int    MQLCALL r_string_array(mql_string*, Indicator*);

MQLAPI void   MQLCALL r_int_array_set(int*, int);
MQLAPI void   MQLCALL r_double_array_set(double*, int);
MQLAPI void   MQLCALL r_string_array_set(mql_string*, int);

MQLAPI Indicator* MQLCALL ind_init(char*, char*, int);
MQLAPI int        MQLCALL ind_get_all(mql_string*);
MQLAPI int        MQLCALL ind_find(char *name, int *arr, mql_string *str_arr);
MQLAPI void       MQLCALL ind_finish(Indicator*);
}

bool r_close_socket(SOCKET sd);

void SetupFDSets(fd_set& ReadFDs, fd_set& WriteFDs, fd_set& ExceptFDs, SOCKET ListeningSocket = INVALID_SOCKET)
{
    FD_ZERO(&ReadFDs);
    FD_ZERO(&WriteFDs);
    FD_ZERO(&ExceptFDs);

    // Add the listener socket to the read and except FD sets, if there
    // is one.
    if (ListeningSocket != INVALID_SOCKET) {
        FD_SET(ListeningSocket, &ReadFDs);
        FD_SET(ListeningSocket, &ExceptFDs);
    }

    // Add client connections
    for(SOCKET s : gConnections) {
        FD_SET(s, &ReadFDs);
        FD_SET(s, &ExceptFDs);
    }
}

SOCKET s_accept(SOCKET ListeningSocket, timeval *tv)
{
    sockaddr_in from;
    int nAddrSize = sizeof(from);

    fd_set ReadFDs, WriteFDs, ExceptFDs;
    SetupFDSets(ReadFDs, WriteFDs, ExceptFDs, ListeningSocket);

    int ret = select(0, &ReadFDs, NULL, &ExceptFDs, tv);

    if(ret > 0) {
        //// Something happened on one of the sockets.
        // Was it the listener socket?...
        if (FD_ISSET(ListeningSocket, &ReadFDs)) {
            SOCKET sd = accept(ListeningSocket, (sockaddr*)&from, &nAddrSize);

            if (sd != INVALID_SOCKET) {
                // Tell user we accepted the socket, and add it to
                // our connecition list.
                std::cout << "Accepted connection from " << inet_ntoa(from.sin_addr) << ":" << ntohs(from.sin_port)
                << ", socket " << sd << "." << std::endl;

                gConnections.push_back(sd);

                if ((gConnections.size() + 1) > 64)
                    std::cout << "WARNING: More than 63 client connections accepted."
                    << " This will not work reliably on some Winsock stacks!" << std::endl;

                // Mark the socket as non-blocking, for safety.
                u_long nNoBlock = 1;
                ioctlsocket(sd, FIONBIO, &nNoBlock);
                return(sd);
            }
            else {
                std::cerr << "accept() failed: " << WSAGetLastError() << std::endl;
                return INVALID_SOCKET;
            }
        }
        else if (FD_ISSET(ListeningSocket, &ExceptFDs)) {
            int err, errlen = sizeof(err);
            getsockopt(ListeningSocket, SOL_SOCKET, SO_ERROR, (char*)&err, &errlen);
            std::cerr << WSAGetLastError() << " Exception on listening socket: " << err << std::endl;
            return INVALID_SOCKET;
        }
    }
    else if(ret == SOCKET_ERROR)
        std::cerr << "select() failed in check_accept(" << ListeningSocket << ") " << WSAGetLastError() << std::endl;

    return INVALID_SOCKET;
}

SOCKET MQLCALL r_init(int port)
{
    WSAData wsaData;
    int ret;
    if((ret = WSAStartup(0x101, &wsaData)) != 0)
        return(WSAGetLastError());

    //u_long nInterfaceAddr = inet_addr("localhost");

    SOCKET sd = socket(AF_INET, SOCK_STREAM, 0);
    if (sd != INVALID_SOCKET) {
        sockaddr_in sinInterface{AF_INET, htons(port), INADDR_ANY};

        if (bind(sd, (sockaddr*)&sinInterface, sizeof(sockaddr_in)) != SOCKET_ERROR) {
            listen(sd, 5);
            return(sd);
        }
        else {
            std::cerr << "bind() failed " << WSAGetLastError() << std::endl;
        }
    }

    return INVALID_SOCKET;
}

SOCKET MQLCALL r_accept(SOCKET s)
{
    return s_accept(s, NULL);
}

SOCKET MQLCALL r_check_accept(SOCKET s)
{
    timeval tv{0, 0};
    return s_accept(s, &tv);
}

SOCKET MQLCALL r_ready_read(SOCKET ListeningSocket)
{
    std::string errstr("error");

    //sockaddr_in sinRemote;
    //int nAddrSize = sizeof(sinRemote);
    timeval tv{0, 1000};

    fd_set ReadFDs, WriteFDs, ExceptFDs;
    SetupFDSets(ReadFDs, WriteFDs, ExceptFDs, ListeningSocket);

    try {
        int ready = select(0, &ReadFDs, NULL, &ExceptFDs, &tv);
        if(ready > 0) {
            for (auto it = gConnections.begin(); it != gConnections.end(); ) {
                std::cerr << "r_ready_read it=" << *it << std::endl;
                if(FD_ISSET(*it, &ExceptFDs)) {
                    // Something bad happened on the socket, or the client closed its half of the connection.
                    std::cerr << "r_ready_read exception on " << *it << std::endl;
                    FD_CLR(*it, &ExceptFDs);
                    int err, errlen = sizeof(err);
                    getsockopt(*it, SOL_SOCKET, SO_ERROR, reinterpret_cast<char*>(&err), &errlen);
                    if(err != NO_ERROR)
                        throw err;
                    r_close(*it);   // Shut the conn down and remove it from the list.
                    gConnections.erase(it);
                    it = gConnections.begin();
                }
                else if(FD_ISSET(*it, &ReadFDs)) {
                    //Socket readable; handling it
                    std::cerr << "r_ready_read readable " << *it << std::endl;
                    return *it;
                }
                else {
                    ++it;
                }
            }
        }
        else if(ready == SOCKET_ERROR)
            throw WSAGetLastError();
    }
    catch(int e) {
        std::cerr << "r_read " << errstr << ": " << e << std::endl;
    }
    return INVALID_SOCKET;
}

int MQLCALL r_packet_return(SOCKET c)
{
    int r;
    unsigned short len;
    void *ptr;

    try {
        std::cerr << " :: r_packet_return" << std::endl;

        msgpack::sbuffer sbuf;
        msgpack::packer<msgpack::sbuffer> packer(&sbuf);
        packer.pack_array(!int_array.empty() + !double_array.empty() + !string_array.empty());

        if(int_array.size() > 0)
            packer.pack(int_array);
        if(double_array.size() > 0)
            packer.pack(double_array);
        if(string_array.size() > 0)
            packer.pack(string_array);

        len = sbuf.size();
        ptr = sbuf.data();

        std::cerr << " :: r_packet_return packed bytes " << len << std::endl;

        r = send(c, (char*)&len, 2, 0);
        if(r == SOCKET_ERROR)
            throw WSAGetLastError();
        else if(r != sizeof(len))
            throw;

        r = send(c, (char*)ptr, len, 0);
        if(r == SOCKET_ERROR)
            throw WSAGetLastError();
        else if(r != len)
            throw;

        return 1;
    }
    catch(int wsaerr) {
        std::cerr << "send error: " << wsaerr << std::endl;
    }
    catch(bad_alloc&) {
        std::cerr << "send error: alloc failed" << std::endl;
    }
    catch(...) {
        std::cerr << "send: connection closed" << std::endl;
    }
    return -1;
}

void MQLCALL r_array_size(int *size, Indicator *ind)
{
    if(ind == nullptr) {
        size[0] = int_array.size();
        size[1] = double_array.size();
        size[2] = string_array.size();
    }
    else {
        size[0] = ind->ints.size();
        size[1] = ind->doubles.size();
        size[2] = ind->strings.size();
    }
}

int MQLCALL r_int_array(int* arr, Indicator *ind)
{
    auto int_arr = &int_array;
    if(ind != nullptr) {
        int_arr = &ind->ints;
    }

    std::cerr << " :: int_array " << int_arr->size() << " @" << (int)arr << std::endl;
    if(arr == NULL || int_arr->empty())
        return 0;
    std::copy(int_arr->begin(), int_arr->end(), arr);
    return int_arr->size();
}

int MQLCALL r_double_array(double* arr, Indicator *ind)
{
    auto dbl_arr = &double_array;
    if(ind != nullptr) {
        dbl_arr = &ind->doubles;
    }

    std::cerr << " :: double_array " << dbl_arr->size() << std::endl;
    if(arr == NULL || dbl_arr->empty())
        return 0;
    std::copy(dbl_arr->begin(), dbl_arr->end(), arr);
    return dbl_arr->size();
}

int MQLCALL r_string_array(mql_string *arr, Indicator *ind)
{
    auto str_arr = &string_array;
    if(ind != nullptr) {
        str_arr = &ind->strings;
    }

    std::cerr << " :: string_array (" << ind << ") size " << str_arr->size() << std::endl;
    if(arr == NULL || str_arr->empty())
        return 0;

    int i=0;
    char *s_str;

    for(std::string s : *str_arr) {
        strcpy(arr[i].s, s.c_str());
        arr[i].len = s.size()+1;
        i++;
    }

    return str_arr->size();
}

void MQLCALL r_int_array_set(int* arr, int size)
{
    if(size > 0)
        std::cerr << " :: int_array_set " << size << ", " << arr[0] << std::endl;
    else
        std::cerr << " :: int_array_set " << size << std::endl;

    int_array.resize(size);
    if(size > 0)
        std::copy(arr, arr+size, int_array.begin());
}

void MQLCALL r_double_array_set(double* arr, int size)
{
    if(size > 0)
        std::cerr << " :: double_array_set " << size << ", " << arr[0] << std::endl;
    else
        std::cerr << " :: double_array_set " << size << std::endl;

    double_array.resize(size);
    if(size > 0)
        std::copy(arr, arr+size, double_array.begin());
}

void MQLCALL r_string_array_set(mql_string *arr, int size)
{
    if(size > 0)
        std::cerr << " :: string_array_set " << size << ", " << arr[0].len << ' ' << std::string(arr[0].s, arr[0].len) << std::endl;
    else
        std::cerr << " :: string_array_set " << size << std::endl;

    string_array.clear();

    for(int i=0; i<size; i++) {
        string_array.push_back(std::string(arr[i].s));
    }
}

bool MQLCALL r_close(SOCKET sd)
{
    vector<SOCKET>::iterator it = find(gConnections.begin(), gConnections.end(), sd);
    if(it != gConnections.end())
        gConnections.erase(it);

    return r_close_socket(sd);
}

bool r_close_socket(SOCKET sd)
{
    // stop communication in both directions
    if(shutdown(sd, SD_BOTH) == SOCKET_ERROR)
        return false;

    // read pending data
    char acReadBuffer[kBufferSize];
    for(;;) {
        int nNewBytes = recv(sd, acReadBuffer, kBufferSize, 0);
        if (nNewBytes == SOCKET_ERROR)
            return false;
        else if (nNewBytes == 0)
            break;
    }

    return (closesocket(sd) != SOCKET_ERROR);
}

void MQLCALL r_finish(SOCKET s)
{
    for(SOCKET sd : gConnections) {
        r_close_socket(sd);
    }
    shutdown(s, SD_BOTH);

    if(closesocket(s) == SOCKET_ERROR)
        std::cerr << " :: closesocket error! " << WSAGetLastError() << endl;
}

int MQLCALL r_recv_pack(SOCKET c) {
    int r, id, j, ints, doubles, strings, slen;
    unsigned short len;
    char *buf, *alloc, *sbuf;

    std::cerr << " :: r_recv_pack " << c << std::endl;

    try {
        r = recv(c, (char*)&len, 2, 0);
        if(r == SOCKET_ERROR)
            throw WSAGetLastError();
        else if(r != 2) {
            std::cerr << " :: r_recv_pack recv CLOSE (0) error: r=" << r << std::endl;
            r_close(c);
            return SOCKET_ERROR;
        }

        std::cerr << " :: r_recv_pack len=" << len << std::endl;
        alloc = buf = new char[len+1];
        buf[len] = '\0';

        unsigned long len_waiting=0;
        while(len_waiting < len)
            ioctlsocket(c, FIONREAD, &len_waiting);

        r = recv(c, buf, len, 0);

        if(r == SOCKET_ERROR)
            throw WSAGetLastError();
        else if(r != len) {
            std::cerr << "recv CLOSE (0) error: r=" << r << std::endl;
            r_close(c);
            return SOCKET_ERROR;
        }

        msgpack::unpacked pack;
        msgpack::unpack(&pack, buf, len);
        msgpack::object result = pack.get();
        std::vector<msgpack::object> result_arr;
        std::vector<int> tmp_int;

        result.convert(&result_arr);
        result_arr[0].convert(&tmp_int);

        if(!tmp_int.empty() && tmp_int[0] > 500) {
            auto ind = reinterpret_cast<Indicator*>((void*)tmp_int[1]);
            if(!ind || std::find(indicators.begin(), indicators.end(), ind) == indicators.end())
                throw -1;
            // TODO: pass information that indicator is closed

            std::cerr << " :: indicator " << ind << endl;

            result_arr[0].convert(&ind->ints);
            result_arr[1].convert(&ind->doubles);
            result_arr[2].convert(&ind->strings);
            return 1;
        }

        result_arr[0].convert(&int_array);
        result_arr[1].convert(&double_array);
        result_arr[2].convert(&string_array);

        std::cerr << " :: msgpack::unpacked " << result << std::endl;

        return 0;
    }
    catch(int wsaerr) {
        if(wsaerr == 10054) {
            std::cerr << "recv CLOSE error: " << wsaerr << std::endl;
            return SOCKET_ERROR;
        }
        std::cerr << "recv error: " << wsaerr << std::endl;
        return -wsaerr;
    }
    catch(bad_alloc&) {
        std::cerr << "recv error: alloc failed" << std::endl;
        return -2;
    }
    catch(msgpack::type_error&) {
        std::cerr << "msgpack error: bad cast" << std::endl;
        return -3;
    }
    catch(...) {
        std::cerr << "recv packet: error" << std::endl;
        return -4;
    }
    return SOCKET_ERROR;
}

Indicator* MQLCALL ind_init(char *name, char *symbol, int period)
{
    auto ind = new Indicator(std::string(name), std::string(symbol), period);
    indicators.push_back(ind);
    cerr << " :: ind :: new " << std::string(name) << " indicator " << indicators.size()-1 << endl;
    return ind;
}

int MQLCALL ind_get_all(mql_string *arr)
{
    int i = 0;

    for(auto ind_ptr : indicators) {
        strcpy(arr[i].s, ind_ptr->name.c_str());
        arr[i].len = ind_ptr->name.size()+1;
        i++;
    }

    return indicators.size();
}

int MQLCALL ind_find(char *name, int *arr, mql_string *str_arr)
{
    int j = 0;
    auto s = std::string(name);

    for(auto ind : indicators) {
        if(ind->name == s) {
            arr[j*2] = reinterpret_cast<int>(ind);
            arr[j*2+1] = ind->period;
            strcpy(str_arr[j].s, ind->symbol.c_str());
            str_arr[j].len = ind->symbol.size() + 1;

            j++;
        }
    }

    return j;
}

void MQLCALL ind_finish(Indicator *ind)
{
    auto it = std::find(indicators.begin(), indicators.end(), ind);
    if(it == indicators.end()) {
        std::cerr << " :: INVALID DELETE @" << ind << endl;
        return;
    }

    delete *it;
    indicators.erase(it);
}
