import "@stdlib/deploy";

import "./message";

contract OrderlyAmmDeposit with Deployable {
    balance: Int;

    // OrderlyAmm
    master: Address;

    // The wallet owner
    owner: Address;

    // the JettonWallet belonging to master contract that did the deposit
    jetton_wallet: Address;

    init(master: Address, owner: Address, jetton_wallet: Address) {
        self.balance = 0;
        self.master = master;
        self.owner = owner;
        self.jetton_wallet = jetton_wallet;
    }

    receive(msg: DepositInternal) {
        dump("DepositInternal");
        let ctx: Context = context();
        require(ctx.sender == self.master, "Invalid sender");

        self.balance = self.balance + msg.amount;
        require(self.balance >= 0, "Invalid balance"); 

        send(SendParameters {
            to: msg.responseDestination,
            value: 0,
            bounce: false,
            mode: SendRemainingValue + SendIgnoreErrors,
            body: TokenExcesses { queryId: 0 }.toCell()
        });
    }

    receive(msg: Withdraw) {
        dump("Withdraw");
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");

        self.balance = self.balance - msg.amount;
        require(self.balance >= 0, "Invalid balance");

        send(SendParameters {
            to: self.master,
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: WithdrawInternal {
                queryId: msg.queryId,
                amount: msg.amount,
                destination: self.owner,
                jetton_wallet: self.jetton_wallet,
                responseDestination: ctx.sender
            }.toCell()
        });
    }

    receive(msg: WithdrawAll) {
        dump("WithdrawAll");
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");

        let amount: Int = self.balance;
        require(amount >= 0, "No balance available to withdraw");
        self.balance = 0;

        send(SendParameters {
            to: self.master,
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: WithdrawInternal {
                queryId: msg.queryId,
                amount: amount,
                destination: self.owner,
                jetton_wallet: self.jetton_wallet,
                responseDestination: ctx.sender
            }.toCell()
        });
    }

    receive(msg: AddLiquidityInternal) {
        dump("AddLiquidityInternal");
        let ctx: Context = context();
        require(ctx.sender == self.master, "Invalid sender");

        self.balance = self.balance - msg.amount;
        require(self.balance >= 0, "Invalid balance");

        let queryId: Int = randomInt();

        send(SendParameters {
            to: msg.lpAddress,
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: SendLiquidityToLpInternal {
                queryId: msg.queryId,
                from: self.owner,
                jettonWallet: self.jetton_wallet,
                amount: msg.amount,
                isBase: msg.isBase,
                responseDestination: msg.responseDestination
            }.toCell()
        });
    }

    // receive(msg: SwapInternal) {
    //     dump("SwapInternal");
    //     let ctx: Context = context();
    //     require(ctx.sender == self.master, "Invalid sender");

    //     self.balance = self.balance - msg.amount;
    //     require(self.balance >= 0, "Invalid balance");

    //     send(SendParameters {
    //         to: msg.lpAddress,
    //         value: 0,
    //         bounce: true,
    //         mode: SendRemainingValue,
    //         body: SwapLpInternal {
    //             amount: msg.amount,
    //             side: msg.side,
    //             minOut: msg.minOut,
    //             from: self.owner,
    //             jettonWallet: self.jetton_wallet
    //         }.toCell()
    //     });
    // }

    bounced(src: bounced<WithdrawInternal>) {
        self.balance = self.balance + src.amount;
    }

    bounced(src: bounced<SendLiquidityToLpInternal>) {
        self.balance = self.balance + src.amount;
        // FIXME gas refund doesn't work: https://docs.tact-lang.org/language/guides/bounced#caveats
        // send(SendParameters {
        //     to: src.responseDestination,
        //     value: 0,
        //     bounce: false,
        //     mode: SendRemainingValue + SendIgnoreErrors,
        //     body: TokenExcesses { queryId: 0 }.toCell()
        // });
    }

    bounced(src: bounced<SwapLpInternal>) {
        self.balance = self.balance + src.amount;
    }

    get fun get_deposit_data(): OrderlyDepositData {
        return OrderlyDepositData {
            balance: self.balance,
            master: self.master,
            owner: self.owner,
            jetton_wallet: self.jetton_wallet,
            walletCode: (initOf OrderlyAmmDeposit(self.master, self.owner, self.jetton_wallet)).code
        };
    }
}
