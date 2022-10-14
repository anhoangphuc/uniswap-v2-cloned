import { TestERC20, UniswapV2Factory } from "../typechain-types"
import { SignerWithAddress }from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from "hardhat";
import { expect } from "chai";
import UniswapV2PairBuilt from "../artifacts/contracts/core/UniswapV2Pair.sol/UniswapV2Pair.json";

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

        //Swap two address
        if (tokenA.address > tokenB.address) [tokenA, tokenB] = [tokenB, tokenA];
    })

    it(`Deploy success`, async () => {
        expect(tokenA.address).to.be.properAddress;
        expect(tokenB.address).to.be.properAddress;
        expect(pairFactory.address).to.be.properAddress;
    })

    it(`Create pair success`, async () => {
        await pairFactory.createPair(tokenA.address, tokenB.address);
    })

    it(`Create pair success`, async () => {
        const deployedByteCode = UniswapV2PairBuilt.bytecode;
        const salt = ethers.utils.solidityKeccak256(
            ["address", "address"],
            [tokenA.address, tokenB.address],
        );

        const pairAddress = ethers.utils.getCreate2Address(
            pairFactory.address,
            salt,
            ethers.utils.keccak256(deployedByteCode),
        );

        await expect(pairFactory.createPair(tokenA.address, tokenB.address))
            .to.be.emit(pairFactory, "PairCreated")
            .withArgs(tokenA.address, tokenB.address, pairAddress, 1);
    })
})