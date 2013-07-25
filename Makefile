CXX=i486-mingw32-g++
# -m32 ?

all: server.dll

server.dll: server.cpp
	g++ @^ -o $@ -s -shared -Wl,--kill-at -std=c++11 -lws2_32 -lmsgpack
