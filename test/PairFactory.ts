import { TestERC20, UniswapV2Factory } from "../typechain-types"
import { SignerWithAddress }from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from "hardhat";
import { expect } from "chai";

context("Pair factory", async () => {
    let pairFactory: UniswapV2Factory;
    let tokenA: TestERC20, tokenB: TestERC20;
    let admin: SignerWithAddress, account1: SignerWithAddress, account2: SignerWithAddress;

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
    })

    it(`Deploy success`, async () => {
        expect(tokenA.address).to.be.properAddress;
        expect(tokenB.address).to.be.properAddress;
        expect(pairFactory.address).to.be.properAddress;
    })
})