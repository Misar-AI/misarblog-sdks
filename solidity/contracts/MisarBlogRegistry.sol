// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IMisarBlog.sol";

contract MisarBlogRegistry is IMisarBlog {
    struct ContentRecord {
        address author;
        uint256 timestamp;
        string username;
        string slug;
    }

    mapping(bytes32 => ContentRecord) private _records;

    function registerContent(bytes32 contentHash, string calldata username, string calldata slug) external override {
        require(_records[contentHash].author == address(0), "Already registered");
        _records[contentHash] = ContentRecord({
            author: msg.sender,
            timestamp: block.timestamp,
            username: username,
            slug: slug
        });
        emit ContentRegistered(contentHash, msg.sender, username, slug);
    }

    function verifyArticle(bytes32 contentHash) external view override returns (bool exists, address author, uint256 timestamp) {
        ContentRecord storage rec = _records[contentHash];
        exists = rec.author != address(0);
        author = rec.author;
        timestamp = rec.timestamp;
    }
}
