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
    })

    it(`First mint`, async () => {
        const amount0 = expandTo18Decimals(1);
        await tokenA.connect(account1).mint(amount0);
        const amount1 = expandTo18Decimals(4);
        await tokenB.connect(account1).mint(amount1);

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

})