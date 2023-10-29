import "@nomicfoundation/hardhat-verify";
import { artifacts, ethers, run } from 'hardhat';
import { ConcertTicketContract } from '../typechain-types';
const ConcertTicket: ConcertTicketContract = artifacts.require('ConcertTicket');


async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const args: any[] = [
        {name: "Concert",
        location: "London",
        description: "A concert",
        startTime: 1701169200,
        endTime: 1701183600,
        totalTickets: 1000,
        ticketsSold: 0}
    ]
    const simpleFtsoExample = await ConcertTicket.new(...args);
    console.log("SimpleFtsoExample deployed to:", simpleFtsoExample.address);
    try {

        const result = await run("verify:verify", {
            address: simpleFtsoExample.address,
            constructorArguments: args,
        })

        console.log(result)
    } catch (e: any) {
        console.log(e.message)
    }
    console.log("Deployed contract at:", simpleFtsoExample.address)

}
main().then(() => process.exit(0))