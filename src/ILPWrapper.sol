// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILPWrapper {
    function wrap(uint tokenId) external;
    function onERC721Received(address /*operator*/, address from, uint256 tokenId, bytes memory /*data*/) external returns (bytes4);
    function unwrap(uint tokenId) external;
    function createLPToken(address token0, address token1, uint24 fee) external returns (address);
    function getUserPositions(address user) external view returns (uint[] memory, address[] memory, uint128[] memory);
    function getUserPositionAt(address user, uint index) external view returns (uint, address, uint128);
    function getLPToken(address token0, address token1, uint24 fee) external view returns (address);
    function getNumUserPositions(address user) external view returns (uint);
    function isLPToken(address token) external view returns (bool);
    function getLPTokens() external view returns (address[] memory);
    function getLPTokenAt(uint index) external view returns (address);
    function getNumLPTokens() external view returns (uint);
}