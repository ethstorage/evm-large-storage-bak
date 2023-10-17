// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC5018ForBlob.sol";

interface EthStorageContract {
    function putBlob(bytes32 key, uint256 blobIdx, uint256 length) external payable;

    function get(bytes32 key, bool needDecode, uint256 off, uint256 len) external view returns (bytes memory);

    function remove(bytes32 key) external;

    function hash(bytes32 key) external view returns (bytes24);

    function upfrontPayment() external view returns (uint256);
}

contract ERC5018ForBlob is IERC5018ForBlob, Ownable {

    uint32 BLOB_SIZE = 4096 * 32;
    uint32 DECODE_BLOB_SIZE = 4096 * 31;

    EthStorageContract public storageContract;

    mapping(bytes32 => bytes32[]) internal keyToChunk;
    mapping(bytes32 => uint256) internal chunkSizes;

    function setEthStorageContract(address storageAddress) public onlyOwner {
        storageContract = EthStorageContract(storageAddress);
    }

    function _countChunks(bytes32 key) internal view returns (uint256) {
        return keyToChunk[key].length;
    }

    function _chunkSize(bytes32 key, uint256 chunkId) internal view returns (uint256, bool) {
        if (chunkId >= _countChunks(key)) {
            return (0, false);
        }
        bytes32 chunkKey = keyToChunk[key][chunkId];
        return (chunkSizes[chunkKey], true);
    }

    function _size(bytes32 key) internal view returns (uint256, uint256) {
        uint256 size_ = 0;
        uint256 chunkId_ = 0;
        while (true) {
            (uint256 chunkSize_, bool found) = _chunkSize(key, chunkId_);
            if (!found) {
                break;
            }
            size_ += chunkSize_;
            chunkId_++;
        }

        return (size_, chunkId_);
    }

    function _getChunk(bytes32 key, bool needDecode, uint256 chunkId) internal view returns (bytes memory, bool) {
        (uint256 length,) = _chunkSize(key, chunkId);
        if (length < 1) {
            return (new bytes(0), false);
        }

        bytes memory data = storageContract.get(keyToChunk[key][chunkId], needDecode, 0, length);
        return (data, true);
    }

    function _get(bytes32 key, bool needDecode) internal view returns (bytes memory, bool) {
        (uint256 fileSize, uint256 chunkNum) = _size(key);
        if (chunkNum == 0) {
            return (new bytes(0), false);
        }

        bytes memory concatenatedData = new bytes(fileSize);
        uint256 offset = 0;
        for (uint256 chunkId = 0; chunkId < chunkNum; chunkId++) {
            bytes32 chunkKey = keyToChunk[key][chunkId];
            uint256 length = chunkSizes[chunkKey];
            storageContract.get(chunkKey, needDecode, 0, length);

            assembly {
                returndatacopy(add(add(concatenatedData, offset), 0x20), 0x40, length)
            }
            offset += length;
        }

        return (concatenatedData, true);
    }

    function _removeChunk(bytes32 key, uint256 chunkId) internal returns (bool) {
        require(_countChunks(key) - 1 == chunkId, "only the last chunk can be removed");
        storageContract.remove(keyToChunk[key][chunkId]);
        keyToChunk[key].pop();
        return true;
    }

    function _remove(bytes32 key, uint256 chunkId) internal returns (uint256) {
        require(_countChunks(key) > 0, "the file has no content");

        for (uint256 i = _countChunks(key) - 1; i >= chunkId;) {
            storageContract.remove(keyToChunk[key][chunkId]);
            keyToChunk[key].pop();
            if (i == 0) {
                break;
            } else {
                i--;
            }
        }
        return chunkId;
    }

    function _preparePut(bytes32 key, uint256 chunkId) private {
        require(chunkId <= _countChunks(key), "must replace or append");
        if (chunkId < _countChunks(key)) {
            // replace, delete old blob
            storageContract.remove(keyToChunk[key][chunkId]);
        }
    }

    function _putChunks(
        bytes32 key,
        uint256[] memory chunkIds,
        uint256[] memory sizes
    ) internal {
        uint256 length = chunkIds.length;
        uint256 cost = storageContract.upfrontPayment();
        require(msg.value >= cost * length, "insufficient balance");

        for (uint8 i = 0; i < length; i++) {
            require(sizes[i] <= DECODE_BLOB_SIZE, "invalid chunk length");
            _preparePut(key, chunkIds[i]);

            bytes32 chunkKey = keccak256(abi.encode(msg.sender, block.timestamp, chunkIds[i], i));
            storageContract.putBlob{value : cost}(chunkKey, i, BLOB_SIZE);
            if (chunkIds[i] < _countChunks(key)) {
                // replace
                keyToChunk[key][chunkIds[i]] = chunkKey;
            } else {
                // add
                keyToChunk[key].push(chunkKey);
            }
            chunkSizes[chunkKey] = sizes[i];
        }
    }



    // interface methods
    function read(bytes memory name, bool needDecode) public view override returns (bytes memory, bool) {
        return _get(keccak256(name), needDecode);
    }

    function size(bytes memory name) public view override returns (uint256, uint256) {
        return _size(keccak256(name));
    }

    function remove(bytes memory name) public onlyOwner override returns (uint256) {
        return _remove(keccak256(name), 0);
    }

    function countChunks(bytes memory name) public view override returns (uint256) {
        return _countChunks(keccak256(name));
    }

    function readChunk(bytes memory name, bool needDecode, uint256 chunkId) public view override returns (bytes memory, bool) {
        return _getChunk(keccak256(name), needDecode, chunkId);
    }

    function chunkSize(bytes memory name, uint256 chunkId) public view override returns (uint256, bool) {
        return _chunkSize(keccak256(name), chunkId);
    }

    function removeChunk(bytes memory name, uint256 chunkId) public onlyOwner override returns (bool) {
        return _removeChunk(keccak256(name), chunkId);
    }

    function truncate(bytes memory name, uint256 chunkId) public onlyOwner override returns (uint256) {
        return _remove(keccak256(name), chunkId);
    }

    function refund() public onlyOwner override {
        payable(owner()).transfer(address(this).balance);
    }

    function destruct() public onlyOwner override {
        selfdestruct(payable(owner()));
    }

    function getChunkHash(bytes memory name, uint256 chunkId) public view returns (bytes32) {
        bytes32 key = keccak256(name);
        if (chunkId >= _countChunks(key)) {
            return bytes32(0);
        }
        return storageContract.hash(keyToChunk[key][chunkId]);
    }

    // Chunk-based large storage methods
    function writeChunk(bytes memory name, uint256[] memory chunkIds, uint256[] memory sizes) public onlyOwner override payable {
        _putChunks(keccak256(name), chunkIds, sizes);
        refund();
    }

    function upfrontPayment() external override view returns (uint256) {
        return storageContract.upfrontPayment();
    }
}
