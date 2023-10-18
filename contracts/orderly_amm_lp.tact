import "@stdlib/deploy";

import "./message";

contract OrderlyAmmLiquidityPool with Deployable {
    const minTonsForStorage: Int = ton("0.01");
    const gasConsumption: Int = ton("0.01");

    // OrderlyAmm
    master: Address;

    base: Address;
    quote: Address;

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
        send(SendParameters {
            to: context().sender, 
            value: value, 
            bounce: false,
            mode: SendIgnoreErrors,
            body: CreateLpSuccessInternal {
                base: self.base,
                quote: self.quote
            }.toCell()
        });
        self.registered = true;
    }
}
