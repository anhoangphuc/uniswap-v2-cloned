import { BigNumber } from "ethers";

export function expandTo18Decimals(x: number): BigNumber {
    return BigNumber.from(x).mul(BigNumber.from(10).pow(18));
}