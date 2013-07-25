CXX=i486-mingw32-g++
# -m32 ?
#CXXFLAGS= -static-libgcc -static-libstdc++

all: server.dll

server.dll: server.cpp
	$(CXX) $^ -o $@ -s -shared -Wl,--kill-at -std=c++11 -lws2_32 -lmsgpack
