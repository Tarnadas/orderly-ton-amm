import "@stdlib/deploy";

import "./message";
import "./jetton_master";
import "./orderly_amm_deposit";

contract OrderlyAmmLiquidityPool with Deployable {
    const minTonsForStorage: Int = ton("0.01");
    const gasConsumption: Int = ton("0.01");
    const minGasCreateLp: Int = ton("0.05");

    // OrderlyAmm
    master: Address;

    base: Address;
    baseAmount: Int as coins = 0;
    quote: Address;
    quoteAmount: Int as coins = 0;

    pricePerShare: Int? as uint128 = null;
    pendingQueries: map<Int, PendingQuery>;

    registered: Bool = false;

    init(master: Address, base: Address, quote: Address) {
        self.master = master;
        self.base = base;
        self.quote = quote;
    }

    receive(msg: CreateLpInternal) {
        dump("CreateLpInternal");
        let ctx: Context = context();
        require(ctx.sender == self.master, "Invalid sender");

        require(!self.registered, "Liquidity pool already registered");

        let value: Int = min(
            myBalance() - self.minTonsForStorage,
            ctx.value - ctx.readForwardFee() - self.gasConsumption - self.minTonsForStorage
        );
        require(value >= self.minGasCreateLp, "Insufficient gas");

        send(SendParameters {
            to: context().sender, 
            value: value, 
            bounce: false,
            mode: SendIgnoreErrors,
            body: CreateLpSuccessInternal {
                base: self.base,
                quote: self.quote,
                responseDestination: msg.responseDestination
            }.toCell()
        });
        self.registered = true;
    }

    receive(msg: SendLiquidityToLpInternal) {
        dump("SendLiquidityToLpInternal");
        let ctx: Context = context();
        let stateInit: StateInit = initOf OrderlyAmmDeposit(self.master, msg.from, msg.jettonWallet);
        require(ctx.sender == contractAddress(stateInit), "Invalid sender");

        let query: PendingQuery? = self.pendingQueries.get(msg.queryId);
        if (query == null) {
            self.pendingQueries.set(msg.queryId, PendingQuery {
                amount: msg.amount,
                isBase: msg.isBase
            });
        } else {
            let amount: Int = 0;
            let queryNonNull: PendingQuery = query!!;
            self.pendingQueries.set(msg.queryId, null);
            if (self.pricePerShare == null) {
                if (msg.isBase) {
                    self.pricePerShare = queryNonNull.amount * 2;
                } else {
                    self.pricePerShare = msg.amount * 2;
                }
                amount = ton("1");
            } else {
                let pricePerShare: Int = self.pricePerShare!!;
                if (msg.isBase) {
                    amount = (queryNonNull.amount + msg.amount * self.quoteAmount / self.baseAmount) * ton("1") / pricePerShare;
                } else {
                    amount = (msg.amount + queryNonNull.amount * self.quoteAmount / self.baseAmount) * ton("1") / pricePerShare;
                }
            }
            if (msg.isBase) {
                self.baseAmount = self.baseAmount + msg.amount;
                self.quoteAmount = self.quoteAmount + queryNonNull.amount;
            } else {
                self.baseAmount = self.baseAmount + queryNonNull.amount;
                self.quoteAmount = self.quoteAmount + msg.amount;
            }

            let sharesInit: StateInit = initOf JettonMaster(myAddress(), emptyCell()); // TODO on-chain metadata
            send(SendParameters {
                to: contractAddress(sharesInit),
                value: 0, 
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: Mint {
                    amount: amount,
                    receiver: msg.from,
                    responseDestination: msg.responseDestination
                }.toCell(),
                code: sharesInit.code,
                data: sharesInit.data
            });
        }
    }

    receive(msg: SwapInternal) {
        dump("SwapInternal");
        let ctx: Context = context();
        require(ctx.sender == self.master, "Invalid sender");
    }

    get fun get_shares_address(): Address {
        let stateInit: StateInit = initOf JettonMaster(myAddress(), emptyCell());
        return contractAddress(stateInit);
    }
}
