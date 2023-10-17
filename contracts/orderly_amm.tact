import "@stdlib/deploy";
import "@stdlib/ownable";
import "./message";
import "./orderly_amm_deposit";

contract OrderlyAmm with Deployable, Ownable {
    owner: Address;
    assets: map<Address, Int>;        

    const DEPOSIT: Int = 0;
    const SWAP: Int = 1;

    init(owner: Address) {
        self.owner = owner;
        self.assets = emptyMap();
    }

    receive("refund") {}

    receive(msg: WithdrawInternal) {
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
        dump("msg.from");
        // dump(msg.from.asComment());
        dump(beginCell().storeAddress(msg.from).endCell().hash());
        let ctx: Context = context();
        dump("ctx.sender");
        dump(beginCell().storeAddress(ctx.sender).endCell().hash());

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
        }
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
}
