// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20Balance {
    function balanceOf(address account) external view returns (uint256);
}

/// @title CommunityGate
/// @notice Tier registry + gated channels for a token-gated community.
/// @dev Tiers are defined by a minimum token balance. A member's tier is
///      always the highest *active* tier whose minimum they meet, so tiers
///      are evaluated by threshold, not by insertion order. Channels gate
///      posting on a minimum balance (not on a named tier) so a channel can
///      stay open when tiers are renamed or re-thresholded.
contract CommunityGate {
    IERC20Balance public immutable token;
    address public owner;
    bool public paused;

    struct Tier {
        string name;
        uint256 minBalance;
        bool active;
        bool exists;
    }

    struct Channel {
        string name;
        uint256 requiredMinBalance;
        bool active;
        bool exists;
    }

    struct Post {
        address author;
        uint256 channelId;
        string content;
        uint256 timestamp;
    }

    uint256 public nextTierId;
    uint256 public nextChannelId;
    mapping(uint256 => Tier) public tiers;
    mapping(uint256 => Channel) public channels;
    Post[] public posts;
    mapping(uint256 => uint256[]) private channelPostIndices;

    event TierAdded(uint256 indexed tierId, string name, uint256 minBalance);
    event TierUpdated(uint256 indexed tierId, string name, uint256 minBalance);
    event TierActiveChanged(uint256 indexed tierId, bool active);
    event ChannelCreated(uint256 indexed channelId, string name, uint256 requiredMinBalance);
    event ChannelActiveChanged(uint256 indexed channelId, bool active);
    event MessagePosted(uint256 indexed channelId, address indexed author, uint256 postId);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    error NotOwner();
    error ZeroAddress();
    error EmptyName();
    error UnknownTier();
    error UnknownChannel();
    error EmptyContent();
    error NotMember();
    error InsufficientBalance();
    error ChannelInactive();
    error PausedGate();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedGate();
        _;
    }

    constructor(address token_, address owner_) {
        if (token_ == address(0) || owner_ == address(0)) revert ZeroAddress();
        token = IERC20Balance(token_);
        owner = owner_;
    }

    // ---- Tiers ----

    function addTier(string calldata name_, uint256 minBalance) external onlyOwner returns (uint256 tierId) {
        if (bytes(name_).length == 0) revert EmptyName();
        tierId = nextTierId++;
        tiers[tierId] = Tier({name: name_, minBalance: minBalance, active: true, exists: true});
        emit TierAdded(tierId, name_, minBalance);
    }

    function updateTier(uint256 tierId, string calldata name_, uint256 minBalance) external onlyOwner {
        if (!tiers[tierId].exists) revert UnknownTier();
        if (bytes(name_).length == 0) revert EmptyName();
        tiers[tierId].name = name_;
        tiers[tierId].minBalance = minBalance;
        emit TierUpdated(tierId, name_, minBalance);
    }

    function setTierActive(uint256 tierId, bool active) external onlyOwner {
        if (!tiers[tierId].exists) revert UnknownTier();
        tiers[tierId].active = active;
        emit TierActiveChanged(tierId, active);
    }

    /// @return hasTier Whether the user meets any active tier.
    /// @return tierId The highest active tier met (by minBalance), or 0 when none.
    /// @return name The name of that tier, or "" when none.
    function tierOf(address user) public view returns (bool hasTier, uint256 tierId, string memory name) {
        uint256 balance = token.balanceOf(user);
        uint256 bestMin = 0;
        bool found = false;
        for (uint256 i = 0; i < nextTierId; i++) {
            Tier storage t = tiers[i];
            if (!t.exists || !t.active) continue;
            if (balance < t.minBalance) continue;
            if (!found || t.minBalance > bestMin) {
                found = true;
                bestMin = t.minBalance;
                tierId = i;
                name = t.name;
            }
        }
        return (found, tierId, name);
    }

    function isMember(address user) public view returns (bool) {
        return token.balanceOf(user) > 0;
    }

    function checkAccess(address user, uint256 requiredMinBalance) public view returns (bool) {
        return token.balanceOf(user) >= requiredMinBalance;
    }

    // ---- Channels + posts ----

    function createChannel(string calldata name_, uint256 requiredMinBalance)
        external
        onlyOwner
        returns (uint256 channelId)
    {
        if (bytes(name_).length == 0) revert EmptyName();
        channelId = nextChannelId++;
        channels[channelId] = Channel({
            name: name_,
            requiredMinBalance: requiredMinBalance,
            active: true,
            exists: true
        });
        emit ChannelCreated(channelId, name_, requiredMinBalance);
    }

    function setChannelActive(uint256 channelId, bool active) external onlyOwner {
        if (!channels[channelId].exists) revert UnknownChannel();
        channels[channelId].active = active;
        emit ChannelActiveChanged(channelId, active);
    }

    function postMessage(uint256 channelId, string calldata content)
        external
        whenNotPaused
        returns (uint256 postId)
    {
        Channel storage ch = channels[channelId];
        if (!ch.exists) revert UnknownChannel();
        if (!ch.active) revert ChannelInactive();
        if (bytes(content).length == 0) revert EmptyContent();
        uint256 balance = token.balanceOf(msg.sender);
        if (balance == 0) revert NotMember();
        if (balance < ch.requiredMinBalance) revert InsufficientBalance();
        postId = posts.length;
        posts.push(Post({author: msg.sender, channelId: channelId, content: content, timestamp: block.timestamp}));
        channelPostIndices[channelId].push(postId);
        emit MessagePosted(channelId, msg.sender, postId);
    }

    function postCount() external view returns (uint256) {
        return posts.length;
    }

    function postsInChannel(uint256 channelId) external view returns (Post[] memory) {
        if (!channels[channelId].exists) revert UnknownChannel();
        uint256[] storage indices = channelPostIndices[channelId];
        Post[] memory result = new Post[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) {
            result[i] = posts[indices[i]];
        }
        return result;
    }

    // ---- Pausing ----

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
}
