import chai from 'chai'
import hardhat from 'hardhat'
import { P2PFund, P2PFundToken } from '../typechain-types'
import {Signer} from 'ethers'
import {time} from '@nomicfoundation/hardhat-network-helpers'
const expect = chai.expect
const ethers=hardhat.ethers
const currentDate=new Date()
/**
 * Note: block.timestamp returns time in seconds, getTime returns time in Milliseconds
 */
const Projects= [
    {
        name: "My First Project",
        //Fund Starts in 24 Hours from the time tests run
        fund_start_date: Math.floor((new Date(currentDate.getTime()+(24*60*60*1000))).getTime()/1000),
        //Fund End A Week After Test Run
        fund_end_date: Math.floor(new Date(currentDate.getTime()+(7*24*60*60*1000)).getTime()/1000),
        //3 means 0.03% of annual returns 
        debt_annual_interest_rate: 3,
        debt_repayment_date: Math.floor(new Date(currentDate.getTime()+(365.25*24*60*60*1000)).getTime()/1000),
        fund_target: 500
    }
]

enum revertMessages{
    ERROR_MSG_SENDER_ZERO="Transaction can not be made by 0 address",
    ERROR_PROJECT_NOT_FOUND="Project with given id not found",
    ERROR_NOT_PROJECT_OWNER="Project's owner is not message sender",
    ERROR_NOT_PROJECT_INVESTOR="investor with given address has not invested in the project",
    FUND_NOT_STARTED="Fundraise for the given project not started yet",
    ERROR_PROJECT_OWNER_NOT_PERMITTED="Investor can not be project owner himself",
    ERROR_FUND_CLOSED="Fundraise for the given project Has Been closed"

}

describe('P2P Fund Contract',async () => {
    let contract_owner: Signer;
    let p2p_token_owner: Signer;
    let investor1: Signer;
    let investor2: Signer;
    let project1_owner: Signer;
    let [investor1_address, investor2_address]: [string, string]=['', '']
    let P2PFundTokenContract: P2PFundToken;
    let P2PFund_Contact: P2PFund;
    before(async()=>{
        [contract_owner, p2p_token_owner, investor1, investor2, project1_owner]=await ethers.getSigners()
        investor1_address=await investor1.getAddress()
        investor2_address=await investor2.getAddress()
        const P2PFund_ContractFactory=await ethers.getContractFactory('P2PFund')
        const P2PToken_ContractFactory=await ethers.getContractFactory('P2PFundToken')
        P2PFundTokenContract= await P2PToken_ContractFactory.connect(p2p_token_owner).deploy('P2P Test Token', 'P2PTTK', 10000)
        await P2PFundTokenContract.deployed()
        console.log(`P2P Fund Token Address is ${P2PFundTokenContract.address}`)
        P2PFund_Contact= await P2PFund_ContractFactory.connect(contract_owner).deploy(P2PFundTokenContract.address)
        await P2PFund_Contact.deployed()
        console.log(`P2P Fund Contract Address is ${P2PFund_Contact.address}`)
    })
    describe("Transfers Of Tokens Before Set Up", function () {
        it("Transferring 100 Token To investor 1", async ()=> {
            await P2PFundTokenContract.transfer(investor1_address, 100);
            const balance=await P2PFundTokenContract.balanceOf(investor1_address)
            expect(balance).to.equal(100);
        });
        it("Transferring 100 Token To investor 2", async ()=> {
            await P2PFundTokenContract.transfer(investor2_address, 100);
            const balance=await P2PFundTokenContract.balanceOf(investor2_address)
            expect(balance).to.equal(100);
        });
    });
    
    describe("Adding Project", async()=>{
        it("Should Add Project 1, with correct values", async()=>{
            const firstProjects=Projects[0]
            const respone=await P2PFund_Contact.connect(project1_owner).addNewProject(
                firstProjects.name,
                firstProjects.fund_start_date,
                firstProjects.fund_end_date,
                firstProjects.debt_annual_interest_rate,
                firstProjects.debt_repayment_date,
                firstProjects.fund_target
            )
            expect(respone).to.emit(P2PFund_Contact, 'NewProjectAdded').withArgs(1)
        })
        it("Project with Id 1, must have values set as defined", async ()=>{
            const response=await P2PFund_Contact.projects_mapping(1)
            //console.log('Response is', response)
            expect(response[0]).to.be.equal(1)
            expect(response[1]).to.be.equal(Projects[0].name)
            expect(response[2]).to.be.equal(await project1_owner.getAddress())
            expect(response[3]).to.be.equal(Projects[0].fund_start_date)
            expect(response[4]).to.be.equal(Projects[0].fund_end_date)
            expect(response[5]).to.be.equal(Projects[0].debt_annual_interest_rate*100)
            expect(response[6]).to.be.equal(Projects[0].debt_repayment_date)
            expect(response[7]).to.be.equal(Projects[0].fund_target)
        })
        //TODO: Add Reverted test Cases Here
    })
    describe("Investing In Project 1", async()=>{
        it("Should Revert When Project Id is Invalid", async()=>{
            expect(P2PFund_Contact.connect(investor1).investInProject(100, 50)).to.be.revertedWith(revertMessages.ERROR_PROJECT_NOT_FOUND)
        })
        it("Should Revert When Project Investor is owner himself", async()=>{
            expect(P2PFund_Contact.connect(project1_owner).investInProject(1, 50)).to.be.revertedWith(revertMessages.ERROR_PROJECT_OWNER_NOT_PERMITTED)
        })
        it("Should Revert When Fund has Not started", async()=>{
            expect(P2PFund_Contact.connect(investor1).investInProject(1, 50)).to.be.revertedWith(revertMessages.FUND_NOT_STARTED)
        })
        it("Enhance Block Time by 1 hour of start time for project 1",async ()=>{
            const firstProjectStartTime=Projects[0].fund_start_date
            const newEpoch=firstProjectStartTime+ 60*60
            await time.setNextBlockTimestamp(newEpoch)
        })
        it("Should revert if investor 1 tries to make investment without approval", async()=>{
            expect(P2PFund_Contact.connect(investor1).investInProject(1, 50)).to.be.reverted
        })
        it("Investor 1 Should Approve smart contract to receive investment tokens", async()=>{
            const respone=await P2PFundTokenContract.connect(investor1).approve(P2PFund_Contact.address, 50)
            const allowance=await P2PFundTokenContract.allowance(investor1_address, P2PFund_Contact.address)
            expect(allowance).to.be.equal(50)
        })
        it("Investment Should Successfully Go Through",async ()=>{
            const response=await P2PFund_Contact.connect(investor1).investInProject(1, 50)
            expect(response).to.emit(P2PFund_Contact, 'NewInvestmentMade').withArgs(
                investor1_address,
                1,
                50
            )
        })
        it("Smart contract should have updated Balance", async()=>{
            expect(await P2PFundTokenContract.balanceOf(P2PFund_Contact.address)).to.be.equal(50)
        })
    })
})
