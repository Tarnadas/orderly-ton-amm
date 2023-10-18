import "@stdlib/deploy";
import "@stdlib/ownable";

import "./message";
import "./orderly_amm_deposit";
import "./orderly_amm_lp";

contract OrderlyAmm with Deployable, Ownable {
    owner: Address;

    lps: map<Int as uint16, LiquidityPool>;   
    lpsLength: Int as uint16 = 0;

    const DEPOSIT: Int = 0;
    const SWAP: Int = 1;

    init(owner: Address) {
        self.owner = owner;
        self.lps = emptyMap();
    }

    receive("refund") {}

    receive(msg: WithdrawInternal) {
        dump("WithdrawInternal");
        let ctx: Context = context();
        let stateInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), msg.destination, msg.jetton_wallet);
        require(contractAddress(stateInit) == ctx.sender, "Invalid sender");

        send(SendParameters {
            to: msg.jetton_wallet,
            value: 0,
            mode: SendRemainingValue,
            body: TokenTransfer {
                queryId: msg.queryId,
                amount: msg.amount,
                destination: msg.destination,
                response_destination: ctx.sender,
                custom_payload: null,
                forward_ton_amount: 0,
                forward_payload: emptySlice()
            }.toCell()
        });
    }
    
    receive(msg: TokenNotification) {
        dump("TokenNotification");
        let ctx: Context = context();

        if (ctx.value <= ton("0.4")) {
            send(SendParameters {
                to: ctx.sender,
                value: 0,
                mode: SendRemainingValue,
                body: TokenTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    destination: msg.from,
                    response_destination: msg.from,
                    custom_payload: "Insufficient value to process token".asComment(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell()
            });
            return;
        }
        
        let enum: Int = msg.forward_payload.loadUint(8);
        if (enum == self.DEPOSIT) {
            let stateInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), msg.from, ctx.sender);
            send(SendParameters {
                to: contractAddress(stateInit), 
                value: 0, 
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: DepositInternal { 
                    queryId: msg.queryId,
                    amount: msg.amount
                }.toCell(),
                code: stateInit.code,
                data: stateInit.data
            });
        } else if (enum == self.SWAP) {
            let swap: Swap = self.readSwap(msg.forward_payload);
            // TODO
        }
    }

    receive(msg: CreateLp) {
        dump("CreateLp");
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");

        let stateInit: StateInit = initOf OrderlyAmmLiquidityPool(myAddress(), msg.base, msg.quote);
        send(SendParameters {
            to: contractAddress(stateInit), 
            value: 0, 
            bounce: false,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: CreateLpInternal { 
                base: msg.base,
                quote: msg.quote
            }.toCell(),
            code: stateInit.code,
            data: stateInit.data
        });
    }

    receive(msg: CreateLpSuccessInternal) {
        dump("CreateLpSuccessInternal");
        let ctx: Context = context();
        let stateInit: StateInit = initOf OrderlyAmmLiquidityPool(myAddress(), msg.base, msg.quote);
        require(contractAddress(stateInit) == ctx.sender, "Invalid sender");

        self.lps.set(self.lpsLength, LiquidityPool {
            base: msg.base,
            quote: msg.quote
        });
        self.lpsLength = self.lpsLength + 1;
    }

    fun readSwap(msg: Slice): Swap {
        return Swap {
            queryId: msg.loadUint(64),
            tokenOut: msg.loadAddress(),
            minAmount: msg.loadCoins()
        };
    }

    get fun get_deposit_address(owner: Address, jetton_wallet: Address): Address {
        let stateInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), owner, jetton_wallet);
        return contractAddress(stateInit);
    }

    get fun get_lp_address(base: Address, quote: Address): Address {
        let stateInit: StateInit = initOf OrderlyAmmLiquidityPool(myAddress(), base, quote);
        return contractAddress(stateInit);
    }

    get fun get_liquidity_pools(): map<Int as uint16, LiquidityPool> {
        return self.lps;
    }
}
