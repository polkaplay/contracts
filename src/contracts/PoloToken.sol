// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PoloToken is ERC20 {
    constructor () ERC20("PolkaPlay Token", "POLO") public {

        _mint(msg.sender, 1000000000 * 10 ** uint(decimals()));
    }
}