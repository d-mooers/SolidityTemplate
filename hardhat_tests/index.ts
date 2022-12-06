import { expect } from "chai";
import { ethers } from "hardhat";

describe("Contract", function () {
  it("Should pass", async function () {
    const Greeter = await ethers.getContractFactory("Contract");
    const greeter = await Greeter.deploy(10);
    await greeter.deployed();

    expect(await greeter.getAmount()).to.equal(10);

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // wait until the transaction is mined
    // await setGreetingTx.wait();

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
