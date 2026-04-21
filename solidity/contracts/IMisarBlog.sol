// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMisarBlog {
    event ContentRegistered(bytes32 indexed contentHash, address indexed author, string username, string slug);

    function verifyArticle(bytes32 contentHash) external view returns (bool exists, address author, uint256 timestamp);
    function registerContent(bytes32 contentHash, string calldata username, string calldata slug) external;
}
