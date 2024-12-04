// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IJobBoard {
    function create(string memory title, string memory description, address token, uint quantity, uint duration) external returns (uint);
    function fund(uint jobId, uint quantity) external;
    function offer(uint jobId, address candidate) external;
    function getDuration(uint jobId) external view returns (uint);
}