// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./Locker.sol";
import "./Token.sol";
import "./Staker.sol";
import "./ILPWrapper.sol";

contract Launcher is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    address private constant REFI = 0x7dbdBF103Bb03c6bdc584c0699AA1800566f0F84;
    address private constant WETH = 0x4200000000000000000000000000000000000006;
    uint private constant TOKEN = 10**18;
    uint private constant INITIAL_LP = 500000000 * TOKEN;
    uint private constant LP_INCENTIVE = 250000000 * TOKEN;

    uint public STAKING_DURATION = 60 * 60 * 24 * 365; // 1 year

    uint private _nonce;

    struct Project {
        address staker;
        address locker;
    }

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _protocols;
    mapping(address => Project) private _projects;
    mapping(address => EnumerableSet.AddressSet) private _userManagedTokens;
    mapping(address => EnumerableSet.AddressSet) private _userCreatedTokens;

    address private _tokenTemplate;
    address private _stakerTemplate;
    ILPWrapper private _lpWrapper = ILPWrapper(0x80D25C6615BA03757619aB427c2D995D8B695162);

    Locker private _locker;

    constructor() {
        _tokenTemplate = address(new Token());
        _stakerTemplate = address(new Staker());
        _locker = new Locker();

        _protocols.add(address(this));
    }

    function launch(address owner, string memory name, string memory ticker, string memory icon) external payable {
        require(_protocols.contains(msg.sender), "Not authorized");

        _launch(owner, name, ticker, icon);
    }

    function launch(string memory name, string memory ticker, string memory icon) external payable {
        _launch(msg.sender, name, ticker, icon);
    }

    function _launch(address creator, string memory name, string memory ticker, string memory icon) internal {
        address token = Clones.cloneDeterministic(address(_tokenTemplate), bytes32(_nonce++));
        Token(token).init(creator, name, ticker, icon, INITIAL_LP + LP_INCENTIVE);
        _userCreatedTokens[creator].add(token);
        _userManagedTokens[creator].add(token);
        _tokens.add(token);
        _protocols.add(token);

        Token(token).approve(address(_locker), INITIAL_LP);
        _locker.createAndFundLP{value: msg.value}(token, INITIAL_LP);
        _projects[token].locker = address(_locker);

        // Create the Staker
        address staker = Clones.cloneDeterministic(address(_stakerTemplate), bytes32(_nonce++));
        Token(token).approve(address(staker), LP_INCENTIVE);
        Staker(staker).init(token, address(this));
        _projects[token].staker = staker;
        _protocols.add(staker);

        // Create the Staking incentives
        address LP20 = _lpWrapper.createLPToken(token, WETH, 10000);
        Staker(staker).createStakePool(address(this), LP20, LP_INCENTIVE * 24 / 25, STAKING_DURATION);
        Staker(staker).createStakePool(address(this), REFI, LP_INCENTIVE * 1 / 25, STAKING_DURATION);

        _tokens.add(token);
    }

    function updateOwner(address oldOwner, address newOwner) external {
        address token = msg.sender;
        _userManagedTokens[oldOwner].remove(token);
        if (newOwner != address(0)) {
            _userManagedTokens[newOwner].add(token);
        }
    }

    function updateLPWrapper(address newLPWrapper) onlyOwner external {
        _lpWrapper = ILPWrapper(newLPWrapper);
    }

    function updateStakerTemplate(address newTemplate) onlyOwner external {
        _stakerTemplate = newTemplate;
    }

    function updateTokenTemplate(address newTemplate) onlyOwner external {
        _tokenTemplate = newTemplate;
    }

    function updateLocker(address payable newLocker) onlyOwner external {
        _locker = Locker(newLocker);
    }

    function updateStakingDuration(uint newDuration) onlyOwner external {
        require(newDuration >= 4 weeks, "Minimum staking duration of 4 weeks");
        STAKING_DURATION = newDuration;
    }

    function activateProtocol(address protocol) onlyOwner external {
        _protocols.add(protocol);
    }

    function deactivateProtocol(address protocol) onlyOwner external {
        _protocols.remove(protocol);
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

    function getTokenStaker(address token) external view returns (address) {
        return _projects[token].staker;
    }

    function getTokenLocker(address token) external view returns (address) {
        return _projects[token].locker;
    }
}
