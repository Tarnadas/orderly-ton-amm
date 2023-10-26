message Mint {
    amount: Int;
    receiver: Address;
    responseDestination: Address;
}

struct JettonData {
    totalSupply: Int;
    mintable: Bool;
    owner: Address;
    content: Cell;
    walletCode: Cell;
}

struct JettonWalletData {
    balance: Int;
    owner: Address;
    master: Address;
    walletCode: Cell;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    response_destination: Address;
    custom_payload: Cell?;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining; // Comment Text message when Transfer the jetton
}

message(0x178d4519) TokenTransferInternal {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    response_destination: Address;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining; // Comment Text message when Transfer the jetton
}

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining; // Comment Text message when Transfer the jetton 
}

message(0x595f07bc) TokenBurn {
    queryId: Int as uint64;
    amount: Int as coins;
    response_destination: Address;
    custom_payload: Cell?;
}

message(0x7bdd97de) TokenBurnNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    response_destination: Address;
}

message(0xd53276db) TokenExcesses {
    queryId: Int as uint64;
}

message TokenUpdateContent {
    content: Cell;
}

struct OrderlyDepositData {
    balance: Int;
    master: Address;
    owner: Address;
    jetton_wallet: Address;
    walletCode: Cell;
}

message(0x12345678) DepositInternal {
    queryId: Int as uint64;
    amount: Int as coins;
    responseDestination: Address;
}

message Withdraw {
    queryId: Int as uint64;
    amount: Int as coins;
}

message WithdrawAll {
    queryId: Int as uint64;
}

message WithdrawInternal {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    jetton_wallet: Address;
    responseDestination: Address;
}

message Swap {
    // routeLength: Int as uint8;
    // route: map<Int, RouteEntry>;
    lpAddress: Address;
    side: Bool; // true = buy, false = sell
    minOut: Int as coins;
}

// struct RouteEntry {
//     lpAddress: Address;
//     side: Bool; // true = buy, false = sell
//     minOut: Int as coins;
// }

message SwapInternal {
    amount: Int as coins;
    lpAddress: Address;
    side: Bool; // true = buy, false = sell
    minOut: Int as coins;
}

message SwapLpInternal {
    amount: Int as coins;
    side: Bool; // true = buy, false = sell
    minOut: Int as coins;
    from: Address;
    jettonWallet: Address;
}

message CreateLp {
    base: Address;
    quote: Address;
}

message CreateLpInternal {
    responseDestination: Address;
}

message CreateLpSuccessInternal {
    base: Address;
    quote: Address;
    responseDestination: Address;
}

message LiquidityPool {
    base: Address;
    quote: Address;
}

message AddLiquidity {
    base: Address;
    baseAmount: Int as coins;
    baseWallet: Address;
    quote: Address;
    quoteAmount: Int as coins;
    quoteWallet: Address;
}

message AddLiquidityInternal {
    queryId: Int;
    amount: Int as coins;
    lpAddress: Address;
    isBase: Bool;
    responseDestination: Address;
}

message SendLiquidityToLpInternal {
    amount: Int as coins;
    queryId: Int;
    from: Address;
    jettonWallet: Address;
    isBase: Bool;
    responseDestination: Address;
}

struct PendingQuery {
    amount: Int as coins;
    isBase: Bool;
}
