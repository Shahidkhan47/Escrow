// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {console} from "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
contract Escrow {
    address public owner;
    uint256 internal feePercentage;

    constructor(uint _feePercentage) {
        owner = msg.sender;
        feePercentage = _feePercentage;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner can call this function");
        _;
    }
    enum Status {
        QUEUED,
        REFUNDED,
        COMPLETED
    }

    enum CurrencyChoice {
        ETH,
        TOKEN
    }

    struct Deal {
        address buyer;
        address seller;
        CurrencyChoice currencychoice;
        address tokenAddr;
        uint256 value;
        uint256 startTime;
        uint256 endTime;
        Status status;
        uint256 fee;
    }

    bytes32[] internal Identifiers;
    mapping(bytes32 => Deal) internal dealDetails;

    function setFee(uint256 _percentage) external onlyOwner {
        require(_percentage <= 1_000, "Maximum percentage is 10");
        feePercentage = _percentage;
    }

    function dealToken(
        address _seller,
        address _tokenAddr,
        uint256 _value,
        uint256 _endTime
    ) external returns(bytes32 _iden){
        require(_seller != address(0), "Wrong seller address");
        require(_tokenAddr != address(0), "Wrong token address");
        require(
            IERC20(_tokenAddr).balanceOf(msg.sender) >= _value,
            "Insufficient Balance"
        );
        require(
            IERC20(_tokenAddr).allowance(msg.sender, address(this)) >= _value,
            "Insufficient Allowance "
        );
        require(
            _endTime > block.timestamp,
            "end time should be more than current time"
        );
         _iden = keccak256(
            abi.encode(block.timestamp, msg.sender, _value)
        );
        dealDetails[_iden] = Deal({
            buyer: msg.sender,
            seller: _seller,
            currencychoice: CurrencyChoice.TOKEN,
            tokenAddr: _tokenAddr,
            value: _value,
            startTime: block.timestamp,
            endTime: _endTime,
            status: Status.QUEUED,
            fee: 0
        });

        Identifiers.push(_iden);
        IERC20(_tokenAddr).transferFrom(msg.sender, address(this), _value);
        console.log(IERC20(_tokenAddr).balanceOf(address(this)));
        return _iden;
    }

    function dealEth(address _seller, uint256 _endTime) external payable returns(bytes32 _iden) {
        require(_seller != address(0), "Wrong seller address");
        require((msg.sender).balance >= msg.value, "Insufficient Balance");
        require(
            _endTime > block.timestamp,
            "end time should be more than current time"
        );
         _iden = keccak256(
            abi.encode(block.timestamp, msg.sender, msg.value)
        );
        dealDetails[_iden] = Deal({
            buyer: msg.sender,
            seller: _seller,
            currencychoice: CurrencyChoice.ETH,
            tokenAddr: address(0), //It is native token so doesn't have token address
            value: msg.value,
            startTime: block.timestamp,
            endTime: _endTime,
            status: Status.QUEUED,
            fee: 0
        });
        Identifiers.push(_iden);

    }

      function refund(bytes32 _iden) external {
        Deal storage deal = dealDetails[_iden];
        require(deal.buyer == msg.sender, "Only buyer can call this function");
        require(deal.status == Status.QUEUED, "Deal is already resolved");
        require(
            block.timestamp >= deal.startTime &&
                block.timestamp <= deal.endTime,
            "Refund time period is over"
        );
        uint256 fees = commission(deal.value, feePercentage);
        uint256 withdrawValue = deal.value - fees;
        deal.status = Status.REFUNDED;
        deal.fee = fees;
        if (deal.currencychoice == CurrencyChoice.ETH) {
            (bool sent, ) = payable(msg.sender).call{value: withdrawValue}("");
            require(sent, "Transaction failed");
        } else {
            IERC20(deal.tokenAddr).transfer(msg.sender, withdrawValue);
        }
    }

    function withdraw(bytes32 _iden) external {
        Deal storage deal = dealDetails[_iden];
        require(
            deal.seller == msg.sender,
            "Only seller can call this function"
        );
        require(
            block.timestamp >= deal.endTime,
            "You can't withdraw before endtime"
        );
        require(
            deal.status == Status.QUEUED,
            "It is already refunded to buyer"
        );
        uint256 fees = commission(deal.value, feePercentage);
        uint256 withdrawValue = deal.value - fees;
        deal.status = Status.COMPLETED;
        deal.fee = fees;
        if (deal.currencychoice == CurrencyChoice.ETH) {
            (bool sent, ) = msg.sender.call{value: withdrawValue}("");
            require(sent, "Transaction failed");
        } else {
            IERC20(deal.tokenAddr).transfer(
                msg.sender,
                withdrawValue
            );
        }
    }

    function withdrawFees(bytes32 _iden) external payable onlyOwner {
        Deal memory deal = dealDetails[_iden];
        require(deal.status != Status.QUEUED, "Deal still not completed");
        require(
            deal.fee > 0,
            "You have already withdrawed your fees for this deal"
        );
        uint256 withdrawValue = deal.fee;
        if (deal.currencychoice == CurrencyChoice.ETH) {
            (bool sent, ) = payable(msg.sender).call{value: withdrawValue}("");
            require(sent, "Transaction failed");
        } else if (deal.currencychoice == CurrencyChoice.TOKEN) {
            IERC20(deal.tokenAddr).transfer(
                msg.sender,
                withdrawValue
            );
        }
    }

    function chechStatus(bytes32 _iden) external view returns (string memory) {
        Deal memory deal = dealDetails[_iden];
        if (deal.status == Status.QUEUED) {
            return ("Queued");
        } else if (deal.status == Status.REFUNDED) {
            return ("Refunded");
        } else if (deal.status == Status.COMPLETED) {
            return ("Completed");
        } else {
            return ("Unknown");
        }
    }

    function getFeePercentage() public view returns (uint256) {
        return feePercentage;
    }

    function getDealFee(bytes32 _iden)public view returns(uint256){
        Deal memory deal = dealDetails[_iden];
      return deal.fee;
    }

    function checkTime(
        bytes32 _iden
    ) external view returns (uint256, string memory) {
        Deal memory deal = dealDetails[_iden];
        uint256 remainingTime = deal.endTime - block.timestamp;
        if (block.timestamp < deal.endTime) {
            return (remainingTime, "Still in progress");
        } else if (block.timestamp >= deal.endTime) {
            return (0, "Time Over");
        } else {
            return (0, "Unknown");
        }
    }

    function getDetails(
        bytes32 _iden
    )
        external
        view
        returns (address, address, CurrencyChoice, address, uint256, uint256, uint256)
    {
        Deal memory deal = dealDetails[_iden];
        return (
            deal.buyer,
            deal.seller,
            deal.currencychoice,
            deal.tokenAddr,
            deal.value,
            deal.startTime,
            deal.endTime
        );
    }
    
    function getDetails1(
        bytes32 _iden
    )
        external
        view
        returns (Deal memory)
    {
        Deal memory deal = dealDetails[_iden];
        return deal;
    }
    
    function getIden() external view returns (bytes32[] memory) {
        return Identifiers;
    }

    function commission(
        uint256 _value,
        uint256 _percentage
    ) internal pure returns (uint256 cut) {
       cut = (_value * _percentage) / 10000;
    }
}