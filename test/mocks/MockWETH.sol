// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract MockWETH is ERC20("Mock WETH", "WETH", 18) {
    constructor() {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
