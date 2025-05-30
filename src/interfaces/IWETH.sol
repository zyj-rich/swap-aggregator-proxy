
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

interface IWETH {
    function withdraw(uint wad) external;
    function deposit() external payable;
}