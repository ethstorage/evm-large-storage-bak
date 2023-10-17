// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC5018ForBlob {

    function read(bytes memory name, bool needDecode) external view returns (bytes memory, bool);

    // return (size, # of chunks)
    function size(bytes memory name) external view returns (uint256, uint256);

    function remove(bytes memory name) external returns (uint256);

    function countChunks(bytes memory name) external view returns (uint256);

    function readChunk(bytes memory name, bool needDecode, uint256 chunkId) external view returns (bytes memory, bool);

    function chunkSize(bytes memory name, uint256 chunkId) external view returns (uint256, bool);

    function removeChunk(bytes memory name, uint256 chunkId) external returns (bool);

    function truncate(bytes memory name, uint256 chunkId) external returns (uint256);

    function refund() external;

    function destruct() external;

    function getChunkHash(bytes memory name, uint256 chunkId) external view returns (bytes32);

    function writeChunk(bytes memory name, uint256[] memory chunkIds, uint256[] memory sizes) external payable;

    function upfrontPayment() external view returns (uint256);
}
