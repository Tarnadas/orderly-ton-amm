import { CompilerConfig } from '@ton-community/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/orderly_amm_lp.tact',
    options: {
        debug: true,
    },
};
