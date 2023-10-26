import "@stdlib/deploy";

import "./message";
import "./orderly_amm_deposit";
import "./orderly_amm_lp";

contract OrderlyAmm with Deployable {
    const gasForAddLiquidity: Int = ton("0.3");
    const gasConsumptionAddLiquidity: Int = ton("0.06");

    const gasForSwap: Int = ton("0.15");

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
                response_destination: msg.responseDestination,
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
                    amount: msg.amount,
                    responseDestination: msg.from
                }.toCell(),
                code: stateInit.code,
                data: stateInit.data
            });
        } else if (enum == self.SWAP) {
            let swap: Swap = self.readSwap(msg.forward_payload);
            // let i: Int = 0;
            // while (i < swap.routeLength) {
            //     let routeEntry: RouteEntry = swap.route.get(i)!!;
            //     let routeInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), msg.from, ctx.sender);
            //     send(SendParameters {
            //         to: contractAddress(routeInit),
            //         value: self.gasForSwap,
            //         bounce: false,
            //         mode: SendIgnoreErrors,
            //         body: SwapInternal {
            //             amount: msg.amount,
            //             lpAddress: routeEntry.lpAddress,
            //             side: routeEntry.side,
            //             minOut: routeEntry.minOut
            //         }.toCell()
            //     });
            //     i = i + 1;
            // }
            let routeInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), msg.from, ctx.sender);
            send(SendParameters {
                to: contractAddress(routeInit),
                value: self.gasForSwap,
                bounce: false,
                mode: SendIgnoreErrors,
                body: SwapInternal {
                    amount: msg.amount,
                    lpAddress: swap.lpAddress,
                    side: swap.side,
                    minOut: swap.minOut
                }.toCell()
            });
        }
    }

    receive(msg: CreateLp) {
        dump("CreateLp");
        let ctx: Context = context();
        // TODO permissionless listing ok?
        // require(ctx.sender == self.owner, "Invalid sender");

        let stateInit: StateInit = initOf OrderlyAmmLiquidityPool(myAddress(), msg.base, msg.quote);
        send(SendParameters {
            to: contractAddress(stateInit), 
            value: 0, 
            bounce: false,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: CreateLpInternal {
                responseDestination: ctx.sender
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

        send(SendParameters {
            to: msg.responseDestination,
            value: 0,
            bounce: false,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: TokenExcesses { queryId: 0 }.toCell()
        });
    }

    receive(msg: AddLiquidity) {
        dump("AddLiquidity");
        let ctx: Context = context();

        let queryId: Int = randomInt();
        let lpInit: StateInit = initOf OrderlyAmmLiquidityPool(myAddress(), msg.base, msg.quote);
        let lpAddress: Address = contractAddress(lpInit);

        let baseInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), ctx.sender, msg.baseWallet);
        send(SendParameters {
            to: contractAddress(baseInit),
            value: self.gasForAddLiquidity,
            bounce: false,
            mode: SendIgnoreErrors,
            body: AddLiquidityInternal {
                queryId: queryId,
                amount: msg.baseAmount,
                lpAddress: lpAddress,
                isBase: true,
                responseDestination: ctx.sender
            }.toCell()
        });

        let quoteInit: StateInit = initOf OrderlyAmmDeposit(myAddress(), ctx.sender, msg.quoteWallet);
        send(SendParameters {
            to: contractAddress(quoteInit),
            value: self.gasForAddLiquidity,
            bounce: false,
            mode: SendIgnoreErrors,
            body: AddLiquidityInternal {
                queryId: queryId,
                amount: msg.quoteAmount,
                lpAddress: lpAddress,
                isBase: false,
                responseDestination: ctx.sender
            }.toCell()
        });

        let value: Int = ctx.value - 2 * self.gasForAddLiquidity - self.gasConsumptionAddLiquidity - ctx.readForwardFee();
        send(SendParameters {
            to: ctx.sender,
            value: value,
            bounce: false,
            mode: SendIgnoreErrors,
            body: TokenExcesses { queryId: 0 }.toCell()
        });
    }

    // fun readSwap(msg: Slice): Swap {
    //     let routeLength: Int = msg.loadUint(8);
    //     let route: map<Int, RouteEntry> = emptyMap();
    //     let index: Int = 0;
    //     while(index < routeLength) {
    //         let lpAddress: Address = msg.loadAddress();
    //         let sideInt: Int = msg.loadUint(1);
    //         let side: Bool = false;
    //         if (sideInt == 1) {
    //             side = true;
    //         }
    //         let entry: RouteEntry = RouteEntry {
    //             lpAddress: lpAddress,
    //             side: side,
    //             minOut: msg.loadCoins()
    //         };
    //         route.set(index, entry);
    //         index = index + 1;
    //     }
    //     return Swap {
    //         routeLength: routeLength,
    //         route: route
    //     };
    // }

    fun readSwap(msg: Slice): Swap {
        let lpAddress: Address = msg.loadAddress();
        let sideInt: Int = msg.loadUint(1);
        let side: Bool = false;
        if (sideInt == 1) {
            side = true;
        }
        return Swap {
            lpAddress: lpAddress,
            side: side,
            minOut: msg.loadCoins()
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
