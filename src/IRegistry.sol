// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    function isRegistrar(address registrar) external view returns (bool);
}