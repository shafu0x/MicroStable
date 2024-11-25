// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import {Manager, ShUSD} from "../src/MicroStable.sol";
import {MockWETH} from "../test/mocks/MockWETH.sol";

interface Oracle {
    function latestAnswer() external view returns (uint256);
}

contract MicroStableTest is Test {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    ShUSD public stablecoin;
    Manager public manager;
    MockWETH public weth;
    Oracle public oracle = Oracle(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // chainlink eth-usd price feed, eth mainnet

    uint256 ONE_WETH = 1e18;
    uint256 TWO_WETH = 2e18;

    uint256 public constant MIN_COLLAT_RATIO = 1.5e18;

    function setUp() external {
        // fork mainnet for oracle access
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        // mint eth to bob & alice
        vm.deal(bob, 1000e18);
        vm.deal(alice, 1000e18);

        // @todo: the following to be precomputed using vm.computeCreateAddress instead, but will work for now
        address managerContractAddress = 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a;

        // instantiate contracts
        stablecoin = new ShUSD(managerContractAddress);
        weth = new MockWETH();
        manager = new Manager(address(weth), address(stablecoin), address(oracle));
        console2.log(address(manager));

        // mint mock weth to bob & alice
        weth.mint(bob, 1000e18);
        weth.mint(alice, 1000e18);

        // approve max to manager
        vm.prank(bob);
        weth.approve(address(manager), type(uint256).max);
        vm.prank(alice);
        weth.approve(address(manager), type(uint256).max);
    }

    function test_depositCollateral() public {
        depositWeth(bob, ONE_WETH);

        uint256 bobCollateral = manager.address2deposit(bob);
        assertEq(bobCollateral, ONE_WETH);
    }

    function test_withdrawCollateral() public {
        depositWeth(bob, TWO_WETH); // deposit 2 x WETH
        uint256 bobCollateralBeforeWithdrawal = manager.address2deposit(bob);

        withdrawWeth(bob, ONE_WETH); // withdraw 1 x WETH
        uint256 bobCollateralAfterWithdrawal = manager.address2deposit(bob);

        assertEq(bobCollateralBeforeWithdrawal, TWO_WETH);
        assertEq(bobCollateralAfterWithdrawal, ONE_WETH);
    }

    function test_mintStablecoins(uint256 amount) public {
        amount = bound(amount, 100, calculateMaxMintablePerEthDeposited());

        depositWeth(bob, ONE_WETH);

        mintStablecoins(bob, amount);

        uint256 bobAmountMinted = stablecoin.balanceOf(bob);
        assertEq(bobAmountMinted, amount);
    }

    function test_burnStablecoins(uint256 amount) public {
        amount = bound(amount, 100, calculateMaxMintablePerEthDeposited());

        depositWeth(bob, ONE_WETH);

        mintStablecoins(bob, amount);

        vm.startPrank(bob);
        manager.burn(stablecoin.balanceOf(bob) - 100); // burn all but 100 of bob's tokens
        vm.stopPrank();

        uint256 bobAmountMinted = stablecoin.balanceOf(bob);

        assertEq(bobAmountMinted, 100);
    }

    // === HELPER FUNCTIONS ===
    function depositWeth(address depositer, uint256 depositAmount) public {
        vm.startPrank(depositer);
        manager.deposit(depositAmount);
        vm.stopPrank();
    }

    function withdrawWeth(address withdrawer, uint256 withdrawalAmount) public {
        vm.startPrank(withdrawer);
        manager.withdraw(withdrawalAmount);
        vm.stopPrank();
    }

    function mintStablecoins(address minter, uint256 mintAmount) public {
        vm.startPrank(minter);
        manager.mint(mintAmount);
        vm.stopPrank();
    }

    function calculateMaxMintablePerEthDeposited() public view returns (uint256) {
        uint256 ethPriceInUsd = oracle.latestAnswer();
        uint256 maxMintPerEthDeposited = (ethPriceInUsd * 1e10) / MIN_COLLAT_RATIO;
        uint256 maxMintPerEthWithPrecision = maxMintPerEthDeposited * 1e18;
        return maxMintPerEthWithPrecision;
    }
}
