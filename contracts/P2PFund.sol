// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract P2PFund{
    
    address public FundTokenAddress; 
    enum ProjectFundType{
        DEBT, 
        EQUITY
    }
    /**
        Note Not using an array reduces readability of code 
    **/
    struct Project{
        uint256 project_id;
        string project_name;
        address project_owner;
        uint256 fund_start_date;
        uint256 fund_end_date;
        //ProjectFundType fund_type;
        uint256 debt_annual_interest_rate;
        uint256 debt_repayment_date;
        uint256 fund_target; 
    }
    struct Investment{
        uint256 investment_amount;
        uint256 project_id;
        uint256 timestamp;
    }

    Project[] public projects;
    mapping(address => Investment[]) investments_mapping;
    mapping(uint256 => Project) public projects_mapping;
    mapping(uint256 => uint256) public project_to_net_investment_map; 

    constructor(address _FundTokenAddress){
        require(_FundTokenAddress != address(0), "Fund Token Address Can Not Be A Zero Addresss");
        FundTokenAddress=_FundTokenAddress;
    }

    modifier messageSenderNotZero(){
        require(msg.sender != address(0), "Transaction can not be made by 0 address");
        _;
    }

    function addNewProject(string memory project_name, uint256 fund_start_date, uint256 fund_end_date, uint256 debt_annual_interest_rate, uint256 debt_end_date, uint256 fund_target) public {
    
        Project memory newProject;
        newProject.project_name=project_name;
        newProject.fund_start_date=fund_start_date;
        newProject.fund_end_date=fund_end_date;
        newProject.debt_annual_interest_rate=debt_annual_interest_rate;
        newProject.debt_repayment_date=debt_end_date;
        newProject.fund_target=fund_target;

        if( !(newProject.fund_start_date > block.timestamp && newProject.fund_end_date > newProject.fund_start_date) ){
            revert("Start Date must be greater than current date and end date must be greater than start date"); 
        }
        if(newProject.debt_repayment_date < newProject.fund_end_date){
            revert("Debt repayment date can not be less than fund end date");
        }
        newProject.project_id=projects.length +1;
        newProject.project_owner=msg.sender;
        projects.push(newProject);
        projects_mapping[newProject.project_id]=newProject;
    }

    function investInProject(uint256 projectId, uint256 amount) public messageSenderNotZero{
        require(projects_mapping[projectId].project_owner!=address(0), "Project with given id not found");
        require(projects_mapping[projectId].project_owner!=msg.sender, "Investor can not be project owner himself");

        uint256 alreadyInvestedAmount=project_to_net_investment_map[projectId];
        if(amount>projects_mapping[projectId].fund_target-alreadyInvestedAmount){
            revert("Amount that is being invested can not exceed max fund target required");
        }
        
        Investment memory newInvestment;
        newInvestment.project_id=projectId;
        newInvestment.timestamp=block.timestamp;
        newInvestment.investment_amount=amount;
        project_to_net_investment_map[projectId]+=amount;

        //TODO: Do Token Transfer Logic Here
        investments_mapping[msg.sender].push(newInvestment);
        IERC20(FundTokenAddress).transfer(address(this), amount);
    }

    function releaseFundsToProjectOwner(uint256 projectId) public messageSenderNotZero{
        require(projects_mapping[projectId].project_owner==msg.sender, "Project's owner is not message sender");
        require(projects_mapping[projectId].fund_end_date<block.timestamp, "Fund End Date Has Not Elapsed yet");
        IERC20(FundTokenAddress).transfer(msg.sender, project_to_net_investment_map[projectId]);
    }
}