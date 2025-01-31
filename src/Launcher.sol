// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./TokenFactory.sol";

contract Launcher is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _deployers;
    EnumerableSet.AddressSet private _protocols;

    mapping(address => EnumerableSet.AddressSet) private _userManagedTokens;
    mapping(address => EnumerableSet.AddressSet) private _userCreatedTokens;

    TokenFactory private _tokenFactory;
    uint private _nonce;
    bool private _permissionless;

    string constant ERROR_NOT_AUTHORIZED = "Not authorized";

    constructor() {
        _tokenFactory = new TokenFactory();
        _deployers.add(msg.sender);
        _protocols.add(0x78a57863A1Bed20F82de28b5ac5CCc5F6B1b6699); // Job Board
    }

    function launch(address owner, string memory name, string memory ticker, string memory icon) external payable returns (address) {
        require(_deployers.contains(msg.sender), ERROR_NOT_AUTHORIZED);

        return _launch(owner, name, ticker, icon);
    }

    function launch(string memory name, string memory ticker, string memory icon) external payable returns (address) {
        require(_permissionless, ERROR_NOT_AUTHORIZED);

        return _launch(msg.sender, name, ticker, icon);
    }

    function _launch(address creator, string memory name, string memory ticker, string memory icon) internal returns (address) {
        address token = _tokenFactory.create{value: msg.value}(creator, name, ticker, icon);
        _userCreatedTokens[creator].add(token);
        _userManagedTokens[creator].add(token);
        _tokens.add(token);

        return token;
    }

    function claimFees(address token, address recipient, uint amount) onlyOwner external {
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

    function updateFactory(address newFactory) onlyOwner external {
        _tokenFactory = TokenFactory(newFactory);
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

    function addProtocol(address protocol) onlyOwner external {
        _protocols.add(protocol);
    }

    function removeProtocol(address protocol) onlyOwner external {
        _protocols.remove(protocol);
    }

    function getProtocols() external view returns (address[] memory) {
        return _protocols.values();
    }

    function isProtocol(address protocol) external view returns (bool) {
        return _protocols.contains(protocol);
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
