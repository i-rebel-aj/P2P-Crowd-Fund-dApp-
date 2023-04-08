import chai from 'chai'
import hardhat from 'hardhat'
import { P2PFund, P2PFundToken } from '../typechain-types'
import {Signer} from 'ethers'
const expect = chai.expect
const ethers=hardhat.ethers

describe('P2P Fund Contract',async () => {
    let contract_owner: Signer;
    let p2p_token_owner: Signer;
    let investor1: Signer;
    let investor2: Signer;
    let [investor1_address, investor2_address]: [string, string]=['', '']
    let P2PFundTokenContract: P2PFundToken;
    let P2PFund_Contact: P2PFund;
    before(async()=>{
        [contract_owner, p2p_token_owner, investor1, investor2]=await ethers.getSigners()
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
        
    })
})
