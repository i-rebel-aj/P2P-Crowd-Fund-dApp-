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
    mapping(address => mapping(uint256 => Investment[])) investor_project_mapping;
    mapping(uint256 => Project) public projects_mapping;
    mapping(address => mapping(uint256=>uint256)) project_net_invested_by_investor;
    mapping(uint256 => uint256) public project_to_net_investment_map; 
    
    /**
    * Events
    */
    event NewProjectAdded(uint256 project_id);
    event NewInvestmentMade(address investor_address, uint256 project_id, uint256 amount);
    /**
        Constant Error Messages
    */
    string constant private ERROR_MSG_SENDER_ZERO="Transaction can not be made by 0 address";
    string constant private ERROR_PROJECT_NOT_FOUND="Project with given id not found";
    string constant private ERROR_NOT_PROJECT_OWNER="Project's owner is not message sender";
    string constant private ERROR_NOT_PROJECT_INVESTOR="investor with given address has not invested in the project";
    string constant private ERROR_FUND_NOT_STARTED="Fundraise for the given project not started yet";
    string constant private ERROR_FUND_CLOSED="Fundraise for the given project Has Been closed";
    string constant private ERROR_PROJECT_OWNER_NOT_PERMITTED="Investor can not be project owner himself";
    string constant private ERROR_FUND_NOT_CLOSED="Fund End Date Has Not Elapsed yet";

    constructor(address _FundTokenAddress){
        require(_FundTokenAddress != address(0), "Fund Token Address Can Not Be A Zero Addresss");
        FundTokenAddress=_FundTokenAddress;
    }

    modifier messageSenderNotZero(){
        require(msg.sender != address(0), ERROR_MSG_SENDER_ZERO);
        _;
    }

    modifier projectExists(uint256 projectId){
        require(projects_mapping[projectId].project_owner!=address(0), ERROR_PROJECT_NOT_FOUND);
        _;
    }
    function addNewProject(string memory project_name, uint256 fund_start_date, uint256 fund_end_date, uint256 debt_annual_interest_rate, uint256 debt_end_date, uint256 fund_target) public {
    
        Project memory newProject;
        newProject.project_name=project_name;
        newProject.fund_start_date=fund_start_date;
        newProject.fund_end_date=fund_end_date;
        //Handling Upto 2 Decimal Places
        newProject.debt_annual_interest_rate=debt_annual_interest_rate*100;
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
        emit NewProjectAdded(newProject.project_id);
    }
    function investInProject(uint256 projectId, uint256 amount) public messageSenderNotZero projectExists(projectId){
        require(projects_mapping[projectId].project_owner!=msg.sender, ERROR_PROJECT_OWNER_NOT_PERMITTED);
        require(block.timestamp > projects_mapping[projectId].fund_start_date, ERROR_FUND_NOT_STARTED);
        require(block.timestamp < projects_mapping[projectId].fund_end_date, ERROR_FUND_CLOSED);

        uint256 alreadyInvestedAmount=project_to_net_investment_map[projectId];
        if(amount>projects_mapping[projectId].fund_target-alreadyInvestedAmount){
            revert("Amount that is being invested can not exceed max fund target required");
        }
        
        Investment memory newInvestment;
        newInvestment.project_id=projectId;
        newInvestment.timestamp=block.timestamp;
        newInvestment.investment_amount=amount;
        project_to_net_investment_map[projectId]+=amount;
        investments_mapping[msg.sender].push(newInvestment);
        investor_project_mapping[msg.sender][projectId].push(newInvestment);
        project_net_invested_by_investor[msg.sender][projectId]+=amount;
        IERC20(FundTokenAddress).transferFrom(msg.sender, address(this), amount);

        emit NewInvestmentMade(msg.sender, projectId, amount);
    }

    function releaseFundsToProjectOwner(uint256 projectId) public messageSenderNotZero projectExists(projectId){
        require(projects_mapping[projectId].project_owner==msg.sender, ERROR_NOT_PROJECT_OWNER);
        require(projects_mapping[projectId].fund_end_date<block.timestamp, ERROR_FUND_NOT_CLOSED);
        IERC20(FundTokenAddress).transfer(msg.sender, project_to_net_investment_map[projectId]);
    }

    function payDebtToInvestor(uint256 projectId, address investor_address) public messageSenderNotZero projectExists(projectId){
        require(projects_mapping[projectId].project_owner==msg.sender, ERROR_NOT_PROJECT_OWNER);
        require(projects_mapping[projectId].debt_repayment_date<block.timestamp, "Project Repayment Date Has Not Reached Yet");
        require(project_net_invested_by_investor[investor_address][projectId] > 0, ERROR_NOT_PROJECT_INVESTOR);
        //Takes a year = 365.25 days accounting for leap year, thus 365.25 * 24 * 60 * 60
        uint256 totalSecondsInYear=31557600;
        uint256 amountToBePayed= project_net_invested_by_investor[investor_address][projectId] * 
        (1 + (projects_mapping[projectId].debt_annual_interest_rate/(totalSecondsInYear *100))*
        (block.timestamp - projects_mapping[projectId].fund_end_date) );

        IERC20(FundTokenAddress).transferFrom(msg.sender, investor_address,amountToBePayed);
    }

}