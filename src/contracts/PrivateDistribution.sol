// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BokkyPooBahsDateTimeLibrary.sol";

import "hardhat/console.sol";

contract PrivateDistribution is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event InvestorsAdded(address[] investors, uint256[] tokenAllocations, address caller);

    event InvestorAdded(address indexed investor, address indexed caller, uint256 allocation);

    event WithdrawnTokens(address indexed investor, uint256 value);

    event TransferInvestment(address indexed owner, uint256 value);

    event RecoverToken(address indexed token, uint256 indexed amount);

    uint256 private _totalAllocatedAmount;
    uint256 private _initialTimestamp;
    IERC20 private _poloToken;
    address[] public investors;

    enum AllocationType { SEED, PRIVATE, STRATEGIC }

    struct Investor {
        bool exists;
        uint256 withdrawnTokens;
        uint256 tokensAllotment;
        AllocationType allocationType;
    }

    mapping(address => Investor) public investorsInfo;

    /// @dev Boolean variable that indicates whether the contract was initialized.
    bool public isInitialized = false;

    /// @dev Checks that the contract is initialized.
    modifier initialized() {
        require(isInitialized, "not initialized");
        _;
    }

    /// @dev Checks that the contract is initialized.
    modifier notInitialized() {
        require(!isInitialized, "initialized");
        _;
    }

    modifier onlyInvestor() {
        require(investorsInfo[_msgSender()].exists, "Only investors allowed");
        _;
    }

    constructor(address _token) {
        _poloToken = IERC20(_token);
    }

    function getInitialTimestamp() public view returns (uint256 timestamp) {
        return _initialTimestamp;
    }

    /// @dev Adds investors. This function doesn't limit max gas consumption,
    /// so adding too many investors can cause it to reach the out-of-gas error.
    /// @param _investors The addresses of new investors.
    /// @param _tokenAllocations The amounts of the tokens that belong to each investor.
    function addInvestors(
        address[] calldata _investors,
        uint256[] calldata _tokenAllocations,
        uint256[] calldata _allocationTypes
    ) external onlyOwner {
        require(_investors.length == _tokenAllocations.length, "different arrays sizes");
        for (uint256 i = 0; i < _investors.length; i++) {
            _addInvestor(_investors[i], _tokenAllocations[i], _allocationTypes[i]);
        }
        emit InvestorsAdded(_investors, _tokenAllocations, msg.sender);
    }

    function withdrawTokens() external onlyInvestor() initialized() {
        Investor storage investor = investorsInfo[_msgSender()];

        uint256 tokensAvailable = withdrawableTokens(_msgSender());

        require(tokensAvailable > 0, "no tokens available for withdrawal");

        investor.withdrawnTokens = investor.withdrawnTokens.add(tokensAvailable);
        _poloToken.safeTransfer(_msgSender(), tokensAvailable);

        emit WithdrawnTokens(_msgSender(), tokensAvailable);
    }

    /// @dev The starting time of TGE
    /// @param _timestamp The initial timestamp, this timestap should be used for vesting
    function setInitialTimestamp(uint256 _timestamp) external onlyOwner() notInitialized() {
        isInitialized = true;
        _initialTimestamp = _timestamp;
    }

    /// @dev withdrawble tokens for an address
    /// @param _investor whitelisted investor address
    function withdrawableTokens(address _investor) public view returns (uint256 tokens) {
        Investor storage investor = investorsInfo[_investor];
        uint256 availablePercentage = _calculateAvailablePercentage(investor.allocationType);
        uint256 noOfTokens = _calculatePercentage(investor.tokensAllotment, availablePercentage);
        uint256 tokensAvailable = noOfTokens.sub(investor.withdrawnTokens);

        // console.log("Withdrawable Tokens: %s", tokensAvailable);

        return tokensAvailable;
    }

    /// @dev Adds investor. This function doesn't limit max gas consumption,
    /// so adding too many investors can cause it to reach the out-of-gas error.
    /// @param _investor The addresses of new investors.
    /// @param _tokensAllotment The amounts of the tokens that belong to each investor.
    /// @param _allocationType The allocation type to each investor.
    function _addInvestor(
        address _investor,
        uint256 _tokensAllotment,
        uint256 _allocationType
    ) internal onlyOwner {
        require(_investor != address(0), "Invalid address");
        require(_tokensAllotment > 0, "the investor allocation must be more than 0");
        Investor storage investor = investorsInfo[_investor];

        require(investor.tokensAllotment == 0, "investor already added");

        investor.tokensAllotment = _tokensAllotment;
        investor.exists = true;
        investors.push(_investor);
        investor.allocationType = AllocationType(_allocationType);

        _totalAllocatedAmount = _totalAllocatedAmount.add(_tokensAllotment);
        emit InvestorAdded(_investor, _msgSender(), _tokensAllotment);
    }

    /// @dev calculate percentage value from amount
    /// @param _amount amount input to find the percentage
    /// @param _percentage percentage for an amount
    function _calculatePercentage(uint256 _amount, uint256 _percentage) private pure returns (uint256 percentage) {
        return _amount.mul(_percentage).div(100).div(1e18);
    }

    function _calculateAvailablePercentage(AllocationType allocationType)
        private
        view
        returns (uint256 availablePercentage)
    {
        uint256 initialReleasePercentage;
        uint256 remainingDistroPercentage;
        uint256 currentTimeStamp = block.timestamp;
        uint256 initialCliff = _initialTimestamp + 120 days;
        uint256 vestingDuration = _initialTimestamp + 270 days + 120 days;
        uint256 noOfRemaingDays = 270;

        if (allocationType == AllocationType.PRIVATE) {
            initialReleasePercentage = uint256(15).mul(1e18);
            remainingDistroPercentage = 85;
        } else if (allocationType == AllocationType.SEED) {
            initialReleasePercentage = uint256(10).mul(1e18);
            remainingDistroPercentage = 90;
        }

        // 85/270 = 0.314814815%
        // 90/270 = 0.333333333%

        // 0.314814815*145

        uint256 everyDayReleasePercentage = remainingDistroPercentage.mul(1e18).div(noOfRemaingDays);

        if (currentTimeStamp > _initialTimestamp) {
            if (currentTimeStamp <= initialCliff) {
                return initialReleasePercentage;
            } else if (currentTimeStamp > initialCliff && currentTimeStamp < vestingDuration) {
                uint256 noOfDays = BokkyPooBahsDateTimeLibrary.diffDays(initialCliff, currentTimeStamp);

                uint256 currentUnlockedPercentage = noOfDays.mul(everyDayReleasePercentage);
                // console.log("Everyday Percentage: %s, Days: %s, Current Unlock %: %s",everyDayReleasePercentage, noOfDays, currentUnlockedPercentage);

                return initialReleasePercentage.add(currentUnlockedPercentage);
            } else {
                return uint256(100).mul(1e18);
            }
        }
    }

    function recoverToken(address _token, uint256 amount) external onlyOwner {
        IERC20(_token).safeTransfer(_msgSender(), amount);
        emit RecoverToken(_token, amount);
    }
}
