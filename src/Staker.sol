// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./Pool.sol";

interface IRebased {
    function onStake(address user, address token, uint quantity) external;
    function onUnstake(address user, address token, uint quantity) external;
}

contract Staker is IRebased {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    address private constant REBASE = 0x89fA20b30a88811FBB044821FEC130793185c60B;
    address private _rewardToken;

    EnumerableSet.AddressSet private _tokens;
    mapping(address => EnumerableSet.AddressSet) private _tokenPools;
    mapping(address => EnumerableSet.AddressSet) private _userPools;
    mapping(address => EnumerableMap.AddressToUintMap) private _userTokenStakes;

    address public immutable _poolTemplate;
    uint private _nonce;

    modifier onlyRebase {
        require(msg.sender == REBASE, "Only Rebase");
        _;
    }

    constructor() {
        _poolTemplate = address(new Pool());
    }

    function init(address rewardToken) external {
        require(_rewardToken == address(0), "Already initialized");

        _rewardToken = rewardToken;
    }

    function createStakePool(address stakeToken, address rewardFunder, uint rewardQuantity, uint rewardDuration) external returns (address) {
        require(
            msg.sender == Ownable(_rewardToken).owner(),
            "Not authorized"
        );

        address pool = Clones.cloneDeterministic(address(_poolTemplate), bytes32(_nonce++));
        Pool(pool).init(address(this), rewardQuantity, rewardDuration);

        require(
            IERC20(_rewardToken).transferFrom(rewardFunder, address(this), rewardQuantity),
            "Unable to transfer token"
        );

        _tokenPools[stakeToken].add(pool);
        _tokens.add(stakeToken);

        return pool;
    }

    function onStake(address user, address token, uint quantity) external onlyRebase {
        address[] memory pools = _tokenPools[token].values();
        require(pools.length > 0, "No pools for token");

        EnumerableSet.AddressSet storage userPools = _userPools[user];
        (,uint stake) = _userTokenStakes[user].tryGet(token);
        uint newBalance = stake + quantity;

        for (uint i = 0; i < pools.length; i++) {
            address pool = pools[i];
            if (userPools.contains(pool)) {
                Pool(pool).add(user, quantity);
            } else {
                userPools.add(pool);
                Pool(pool).add(user, newBalance);
            }
        }

        _userTokenStakes[user].set(token, newBalance);
    }

    function onUnstake(address user, address token, uint quantity) external onlyRebase {
        address[] memory pools = _tokenPools[token].values();

        EnumerableSet.AddressSet storage userPools = _userPools[user];
        (,uint stake) = _userTokenStakes[user].tryGet(token);
        require(quantity <= stake, "Invalid unstake amount");

        for (uint i = 0; i < pools.length; i++) {
            address pool = pools[i];
            if (userPools.contains(pool)) {
                Pool(pool).remove(user, quantity);
            }
        }

        _userTokenStakes[user].set(token, stake - quantity);
    }

    function syncPools(address[] memory tokens) external {
        EnumerableSet.AddressSet storage userPools = _userPools[msg.sender];

        for (uint j = 0; j < tokens.length; j++) {
            address token = tokens[j];
            (,uint stake) = _userTokenStakes[msg.sender].tryGet(token);

            if (stake > 0) {
                address[] memory pools = _tokenPools[token].values();
                for (uint i = 0; i < pools.length; i++) {
                    address pool = pools[i];

                    if (!userPools.contains(pool)) {
                        userPools.add(pool);
                        Pool(pool).add(msg.sender, stake);
                    }
                }
            }
        }
    }

    function claimRewards() external {
        address[] memory pools = _userPools[msg.sender].values();
        for (uint i = 0; i < pools.length; i++) {
            uint reward = Pool(pools[i]).payReward(msg.sender);
            if (reward > 0) {
                require(IERC20(_rewardToken).transfer(msg.sender, reward), "Unable to send reward");
            }
        }
    }

    function getRewards(address user) external view returns (uint) {
        uint earned = 0;

        address[] memory pools = _userPools[user].values();
        for (uint i = 0; i < pools.length; i++) {
            earned += Pool(pools[i]).earned(user);
        }

        return earned;
    }

    function getTokens() public view returns (address[] memory) {
        return _tokens.values();
    }

    function getTokenAt(uint index) external view returns (address) {
        return _tokens.at(index);
    }

    function getNumTokens() external view returns (uint) {
        return _tokens.length();
    }

    function getUserPools(address user) external view returns (address[] memory) {
        return _userPools[user].values();
    }

    function getUserPoolAt(address user, uint index) external view returns (address) {
        return _userPools[user].at(index);
    }

    function getNumUserPools(address user) external view returns (uint) {
        return _userPools[user].length();
    }

    function getTokenPools(address token) external view returns (address[] memory) {
        return _tokenPools[token].values();
    }

    function getTokenPoolAt(address token, uint index) external view returns (address) {
        return _tokenPools[token].at(index);
    }

    function getNumTokenPools(address token) external view returns (uint) {
        return _tokenPools[token].length();
    }

    function getUserStake(address user, address token) external view returns (uint) {
        (,uint userStake) = _userTokenStakes[user].tryGet(token);
        return userStake;
    }

    function getUserStakes(address user) external view returns (address[] memory, uint[] memory) {
        EnumerableMap.AddressToUintMap storage userStakes = _userTokenStakes[user];
        address[] memory tokens = userStakes.keys();
        uint[] memory stakes = new uint[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            stakes[i] = userStakes.get(tokens[i]);
        }
        return (tokens, stakes);
    }

    function getUserStakeAt(address user, uint index) external view returns (address, uint) {
        return _userTokenStakes[user].at(index);
    }

    function getNumUserStakes(address user) external view returns (uint) {
        return _userTokenStakes[user].length();
    }

    function getRewardToken() external view returns (address) {
        return _rewardToken;
    }
}
