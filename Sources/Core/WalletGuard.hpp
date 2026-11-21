#pragma once
#include "Gacha.hpp"
#include <stdexcept>

namespace Legend {
struct WalletSignal {
 int stars=-1;
 uint8_t mode=0,load=0,prize=0;
 bool credited=false;
};
WalletSignal readWallet(const uint8_t* ram,size_t size);

struct WalletRejected : std::runtime_error {
 WalletRejected():std::runtime_error("Legend đã dừng phiên có số sao thay đổi ngoài luồng hợp lệ."){}
};
class WalletGuard {
 int expected=-1;
 bool rejected=false;
 [[noreturn]] void reject();
public:
 void establish(int stars);
 void check(WalletSignal signal);
 void update(WalletSignal before,WalletSignal after,const uint8_t* ram,size_t size,const Bytes& savedCard);
 bool blocked()const{return rejected;}
};
}
