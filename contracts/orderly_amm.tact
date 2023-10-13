import "@stdlib/deploy";
import "@stdlib/ownable";
import "./message";

message Add {
    queryId: Int as uint64;
    amount: Int as uint32;
}

message Swap {
    tokenOut: Address;
    minAmount: Int as coins;
}

contract OrderlyAmm with Deployable, Ownable {
    owner: Address;
    counter: Int as uint32;
    assets: map<Address, Int>;        

    init(owner: Address) {
        self.owner = owner;
        self.counter = 0;
        self.assets = emptyMap();
    }

    receive(msg: Add) {
        self.counter = (self.counter + msg.amount);
    }
    
    receive(msg: TokenNotification) {
        let ctx: Context = context();
        let received: Int = msg.amount;
        
        // insufficient value to process token
        if (ctx.value <= ton("0.4")) {
            self.transferJettonTo(
                ctx.sender,
                msg.from,
                received,
                msg.queryId,
                "Insufficient value to process token"
            );
            return;
        }
        
        let swap: Swap = self.readSwap(msg.forward_payload);
        self.transferJettonTo(
            ctx.sender,
            msg.from,
            received,
            msg.queryId,
            "yay"
        );
        // let swap: Slice = msg.forward_payload;
        // if (swap.loadUint(32) != 0x4a2663c4) {
        //     self.transferJettonTo(ctx.sender, msg.from, received,
        //         msg.queryId, "Unknown operation");
        //     return;
        // }
        // let other_jetton_master: Address = swap.loadAddress();
        // let other_jetton_min_expected: Int = swap.loadCoins();
        
        // let other_jw: Address = self.jetton_wallets.get(other_jetton_master)!!;
        // let old_balance_dst: Int = self.assets.get(other_jw)!!;
        // if (other_jetton_min_expected >= old_balance_dst) {
        //     self.transferJettonTo(ctx.sender, msg.from, received,
        //         msg.queryId, "Liquidity pool doesn't have enough funds");
        //     return;
        // }
        // // now, other_jetton_min_expected <= old_balance_dst - 1
        
        // let swap_value: Int = self.calc_swap(old_balance_src!!, old_balance_dst, received);
        // if (swap_value >= old_balance_dst) {  // safeguard against liquidity pool draining
        //     swap_value = old_balance_dst - 1; // still above other_jetton_min_expected, though we still check this next
        // }
        // if (swap_value < other_jetton_min_expected) {
        //     self.transferJettonTo(ctx.sender, msg.from, received,
        //         msg.queryId, "Slippage protection: swap can't give requested count of tokens");
        //     return;
        // }
        
        // self.transferJettonTo(other_jw, msg.from, swap_value, msg.queryId, "Swap completed");
        // self.assets.set(ctx.sender, old_balance_src!! + received);
        // self.assets.set(other_jw, old_balance_dst - swap_value);
        // self.swap_base = self.swap_base + received - swap_value;
    }

    get fun counter(): Int {
        return self.counter;
    }

    fun readSwap(msg: Slice): Swap {
        return Swap {
            tokenOut: msg.loadAddress(),
            minAmount: msg.loadCoins()
        };
    }

    fun transferJettonTo(
        jetton_wallet: Address,
        destination: Address,
        amount: Int,
        queryId: Int,
        message: String
    ) {
        if (amount > 0) {
            send(SendParameters {
                to: jetton_wallet,
                value: 0,
                mode: SendRemainingValue,
                body: TokenTransfer {
                    queryId: queryId,
                    amount: amount,
                    destination: destination,
                    response_destination: destination,
                    custom_payload: message.asComment(),
                    forward_ton_amount: ton("0.000001"),
                    forward_payload: emptySlice()
                }.toCell()
            });
        }
    }
}
