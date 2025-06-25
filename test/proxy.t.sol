// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Proxy} from "../src/SafePalProxy.sol";

contract SafePalBscTest is Test {

    address WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address owner = 0x38b6B88773eAa5267C2Df197716bA0C8f655eB65;
    address commitOwner = 0x38b6B88773eAa5267C2Df197716bA0C8f655eB65;
    address confirmOwner = 0x526d74b9E194a1c3b6eCbB7637d5603e0Ad94891;
    address newExecutor = 0x10eC8F052c653d642c15F7b5D8b4bB13235b8586;
    address oldExecutor = address(0);
    Proxy public proxy = new Proxy(
            WETH,owner,commitOwner,confirmOwner,oldExecutor
        );

    function testCommitOwnerCanSetUnconfirmedExecutor() public {
        //step : commit
        vm.prank(commitOwner);
        proxy.setExecutor(newExecutor);

        assertEq(proxy.UnConfirmExecutor(), newExecutor);
        assertEq(proxy.Executor(), oldExecutor); // Executor shouldn't be updated yet
    }

    function testConfirmOwnerCanConfirmExecutor() public {
        // Step 1: Commit
        vm.prank(commitOwner);
        proxy.setExecutor(newExecutor);

        // Step 2: Confirm
        vm.prank(confirmOwner);
        proxy.setExecutor(newExecutor);

        assertEq(proxy.Executor(), newExecutor);
        assertEq(proxy.UnConfirmExecutor(), address(0));
    }

    function testConfirmWithWrongAddressReverts() public {
        // Step 1: Commit
        vm.prank(commitOwner);
        proxy.setExecutor(newExecutor);

        // Step 2: Confirm with different address
        vm.prank(confirmOwner);
        vm.expectRevert("Executor inconsistent");
        proxy.setExecutor(address(0x777));
    }

    function testFakeUserSetExecutor() public {
        address fakeUser = address(0xa4);
        vm.prank(fakeUser);
        vm.expectRevert("Auth failed");
        proxy.setExecutor(newExecutor);
    }

    function testZeroAddressReverts() public {
        vm.prank(commitOwner);
        vm.expectRevert("Zero executor address");
        proxy.setExecutor(address(0));
    }
}