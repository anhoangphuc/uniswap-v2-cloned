import { TestERC20, UniswapV2Factory } from "../typechain-types"
import { SignerWithAddress }from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from "hardhat";
import { BigNumber, constants } from "ethers";
import { expect } from "chai";
import { UniswapV2Pair } from "../typechain-types/core";
import { expandTo18Decimals } from "./utils";

context("Pair", async () => {
    let pairFactory: UniswapV2Factory;
    let tokenA: TestERC20, tokenB: TestERC20;
    let admin: SignerWithAddress, account1: SignerWithAddress, account2: SignerWithAddress;
    let pair: UniswapV2Pair;
    let MINIMUM_LIQUIDITY: BigNumber;

    beforeEach(async () => {
        [admin, account1, account2] = await ethers.getSigners();
        const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
        pairFactory = await UniswapV2Factory.deploy(admin.address);
        await pairFactory.deployed();

        const TestERC20 = await ethers.getContractFactory("TestERC20");
        tokenA = await TestERC20.deploy("TokenA", "TKA");
        await tokenA.deployed();
        tokenB = await TestERC20.deploy("TokenB", "TKB");
        await tokenB.deployed();

        //Swap two address
        if (tokenA.address > tokenB.address) [tokenA, tokenB] = [tokenB, tokenA];

        await pairFactory.createPair(tokenA.address, tokenB.address);
        const pairAddress = await pairFactory.getPair(tokenA.address, tokenB.address);
        pair = await ethers.getContractAt("UniswapV2Pair", pairAddress);
        MINIMUM_LIQUIDITY = await pair.MINIMUM_LIQUIDITY();
        await tokenA.connect(account1).mint(expandTo18Decimals(1000000));
        await tokenB.connect(account1).mint(expandTo18Decimals(1000000));
    })

    async function addLiquidity(amount0: BigNumber, amount1: BigNumber, account: SignerWithAddress) {
        await tokenA.connect(account).transfer(pair.address, amount0);
        await tokenB.connect(account).transfer(pair.address, amount1);
        await pair.mint(account.address);
    }

    it(`First mint`, async () => {
        const amount0 = expandTo18Decimals(1);
        const amount1 = expandTo18Decimals(4);

        await tokenA.connect(account1).transfer(pair.address, amount0);
        await tokenB.connect(account1).transfer(pair.address, amount1);
        
        const expectedLiquidity = expandTo18Decimals(2);

        await expect(pair.mint(account1.address))
            .to.emit(pair, "Transfer")
            .withArgs(constants.AddressZero, constants.AddressZero, MINIMUM_LIQUIDITY)
            .to.emit(pair, "Transfer")
            .withArgs(constants.AddressZero, account1.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
            .to.emit(pair, "Sync")
            .withArgs(amount0, amount1)
            .to.emit(pair, "Mint")
            .withArgs(admin.address, amount0, amount1);

        const reserves = await pair.getReserves();
        expect(reserves[0]).to.be.equal(amount0);
        expect(reserves[1]).to.be.equal(amount1);
    })

    context(`Swap case`, async () => {
        const swapTestCases: BigNumber[][] = [
            [1, 5, 10, '1662497915624478906'],
            [1, 10, 5, '453305446940074565'],
        
            [2, 5, 10, '2851015155847869602'],
            [2, 10, 5, '831248957812239453'],
        
            [1, 10, 10, '906610893880149131'],
            [1, 100, 100, '987158034397061298'],
            [1, 1000, 1000, '996006981039903216']
        ].map(a => a.map(n => (typeof n === 'string' ? ethers.BigNumber.from(n) : expandTo18Decimals(n))))
        swapTestCases.forEach((swapTestCase, i) => {
            it(`getInputPrice:${i}`, async () => {
            const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase
            await addLiquidity(token0Amount, token1Amount, account1)
            await tokenA.connect(account1).transfer(pair.address, swapAmount)
            await expect(pair.swap(0, expectedOutputAmount.add(1), account1.address, '0x')).to.be.revertedWith(
                'UniswapV2: K'
            )
            await pair.swap(0, expectedOutputAmount, account1.address, '0x')
            })
        })
    })
})