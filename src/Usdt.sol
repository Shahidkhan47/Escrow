// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20  {
    constructor()
        ERC20("MyToken", "USDT")
    {}

    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }
}