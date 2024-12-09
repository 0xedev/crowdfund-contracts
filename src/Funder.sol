// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IJobBoard.sol";
import "./Launcher.sol";

contract Funder {
    address private _token;
    address private _launcher;

    function init(
        address token,
        uint budget,
        address creator,
        string memory name,
        address staker,
        address launcher
    ) external {
        require(_token == address(0), "Already Initialized");
        _token = token;
        _launcher = launcher;

        IERC20(token).transferFrom(msg.sender, address(this), budget);

        IERC20(token).approve(staker, type(uint256).max);

        address board = 0x2D2BB82ab894267C5Ba80D26e9B4f7470315Bdd8;

        IERC20(token).approve(board, budget / 5);

        uint jobId = IJobBoard(board).create(
            string.concat(name, " launch"),
            "Automatically generated at launch",
            token,
            budget / 5,
            365 days
        );

        IJobBoard(board).offer(jobId, creator);
    }

    function fund(address board, uint jobId, uint quantity) external {
        require(Ownable(_token).owner() == msg.sender, "Not authorized");
        require(Launcher(_launcher).isProtocol(board), "Not Job board");
        require(IJobBoard(board).getDuration(jobId) >= 7 days, "Job duration must be at least 7 days");

        IERC20(_token).approve(board, quantity);

        IJobBoard(board).fund(jobId, quantity);
    }

    function preapprove(address protocol, uint amount) external {
        require(Ownable(_token).owner() == msg.sender, "Not authorized");
        require(Launcher(_launcher).isProtocol(protocol), "Unsupported Protocol");
        IERC20(_token).approve(protocol, amount);
    }

    function preapprove(address protocol) external {
        require(Ownable(_token).owner() == msg.sender, "Not authorized");
        require(Launcher(_launcher).isProtocol(protocol), "Unsupported Protocol");
        IERC20(_token).approve(protocol, type(uint256).max);
    }

    function getToken() external view returns (address) {
        return _token;
    }

    function getLauncher() external view returns (address) {
        return _launcher;
    }
}