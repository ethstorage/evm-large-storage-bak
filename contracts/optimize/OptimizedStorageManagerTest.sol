// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OptimizedStorageManager.sol";

contract OptimizedStorageManagerTest is OptimizedStorageManager {
    function get(bytes32 key) public view returns (bytes memory) {
        (bytes memory data, ) = _get(key);
        return data;
    }

    // for gas metering
    function getWithoutView(bytes32 key) public view returns (bytes memory) {
        (bytes memory data, ) = _get(key);
        return data;
    }

    function put(bytes32 key, bytes memory data) public {
        _put(key, data, 0);
    }

    function put2(bytes32 key, bytes memory data) public {
        _put2(key, data, 0);
    }

    function filesize(bytes32 key) public view returns (uint256) {
        return _filesize(key);
    }

    function whereStore(bytes32 key) public view returns (uint256) {
        return _whereStore(key);
    }

    function remove(bytes32 key) public {
        _remove(key);
    }
}
