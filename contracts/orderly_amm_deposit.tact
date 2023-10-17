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
        let ctx: Context = context();
        require(ctx.sender == self.master, "Invalid sender");

        self.balance = self.balance + msg.amount;
        require(self.balance >= 0, "Invalid balance"); 
        
        self.reply("refund".asComment());
    }

    receive(msg: Withdraw) {
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
                jetton_wallet: self.jetton_wallet
            }.toCell()
        });
    }

    receive(msg: WithdrawAll) {
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
                jetton_wallet: self.jetton_wallet
            }.toCell()
        });
    }

    bounced(src: bounced<WithdrawInternal>) {
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
