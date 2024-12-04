// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./Token.sol";

contract Launcher is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _deployers;

    mapping(address => EnumerableSet.AddressSet) private _userManagedTokens;
    mapping(address => EnumerableSet.AddressSet) private _userCreatedTokens;

    address private _tokenTemplate;
    uint private _nonce;
    bool private _permissionless;

    string constant ERROR_NOT_AUTHORIZED = "Not authorized";

    constructor() {
        _tokenTemplate = address(new Token());
        _deployers.add(msg.sender);
    }

    function launch(address owner, string memory name, string memory ticker, string memory icon) external payable {
        require(_deployers.contains(msg.sender), ERROR_NOT_AUTHORIZED);

        _launch(owner, name, ticker, icon);
    }

    function launch(string memory name, string memory ticker, string memory icon) external payable {
        require(_permissionless, ERROR_NOT_AUTHORIZED);

        _launch(msg.sender, name, ticker, icon);
    }

    function _launch(address creator, string memory name, string memory ticker, string memory icon) internal {
        address payable token = payable(Clones.cloneDeterministic(address(_tokenTemplate), bytes32(_nonce++)));
        Token(token).init{value: msg.value}(creator, name, ticker, icon);
        _userCreatedTokens[creator].add(token);
        _userManagedTokens[creator].add(token);
        _tokens.add(token);
    }

    function collectFees(address token, address recipient, uint amount) onlyOwner external {
        IERC20(token).transfer(recipient, amount);
    }

    function setPermissionless(bool permissionless) external onlyOwner {
        _permissionless = permissionless;
    }

    function updateOwner(address oldOwner, address newOwner) external {
        address token = msg.sender;
        require(_userManagedTokens[oldOwner].remove(token), "Token Not Found");
        if (newOwner != address(0)) {
            _userManagedTokens[newOwner].add(token);
        }
    }

    function updateTokenTemplate(address newTemplate) onlyOwner external {
        _tokenTemplate = newTemplate;
    }

    function addDeployer(address deployer) onlyOwner external {
        _deployers.add(deployer);
    }

    function removeDeployer(address deployer) onlyOwner external {
        _deployers.remove(deployer);
    }

    function getDeployers() external view returns (address[] memory) {
        return _deployers.values();
    }

    function getUserManagedTokens(address user) external view returns (address[] memory) {
        return _userManagedTokens[user].values();
    }

    function getUserManagedTokenAt(address user, uint index) external view returns (address) {
        return _userManagedTokens[user].at(index);
    }

    function getNumUserManagedTokens(address user) external view returns (uint) {
        return _userManagedTokens[user].length();
    }

    function getUserCreatedTokens(address user) external view returns (address[] memory) {
        return _userCreatedTokens[user].values();
    }

    function getUserCreatedTokenAt(address user, uint index) external view returns (address) {
        return _userCreatedTokens[user].at(index);
    }

    function getNumUserCreatedTokens(address user) external view returns (uint) {
        return _userCreatedTokens[user].length();
    }

    function getTokens() external view returns (address[] memory) {
        return _tokens.values();
    }

    function getTokenAt(uint index) external view returns (address) {
        return _tokens.at(index);
    }

    function getNumTokens() external view returns (uint) {
        return _tokens.length();
    }
}
