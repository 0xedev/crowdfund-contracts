// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IJobBoard.sol";
import "./IRegistry.sol";

contract Funder {
    using EnumerableSet for EnumerableSet.UintSet;
    
    address private _token;
    EnumerableSet.UintSet private _fundedJobs;
    IRegistry private constant _registry = IRegistry(0x4011AaBAD557be4858E08496Db5B1f506a4e6167);

    function init(address token, uint budget, address creator, string memory name) external {
        require(_token == address(0), "Already Initialized");
        _token = token;

        IERC20(token).transferFrom(msg.sender, address(this), budget);

        IJobBoard _jobBoard = IJobBoard(0x2D2BB82ab894267C5Ba80D26e9B4f7470315Bdd8);

        // 20% of the hiring budget to the creator, over 1 year
        IERC20(token).approve(address(_jobBoard), budget / 5);
        uint jobId = _jobBoard.create(
            string.concat(name, " launch"),
            "Automatically generated at token launch",
            token,
            budget / 5,
            365 days
        );
        _jobBoard.offer(jobId, creator);
        _fundedJobs.add(jobId);
    }

    function fund(address board, uint jobId, uint quantity) external {
        require(Ownable(_token).owner() == msg.sender, "Not authorized");
        require(_registry.isRegistrar(board), "Not Job board");
        require(IJobBoard(board).getDuration(jobId) >= 4 weeks, "Pay duration must be at least 4 weeks");
        IERC20(_token).approve(board, quantity);
        IJobBoard(board).fund(jobId, quantity);
        _fundedJobs.add(jobId);
    }

    function getFundedJobs() external view returns (uint[] memory) {
        return _fundedJobs.values();
    }

    function getFundedJobAt(uint index) external view returns (uint) {
        return _fundedJobs.at(index);
    }

    function getNumFundedJobs() external view returns (uint) {
        return _fundedJobs.length();
    }

    function getRegistry() external pure returns (address) {
        return address(_registry);
    }

    function getToken() external view returns (address) {
        return _token;
    }
}