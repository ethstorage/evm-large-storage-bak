// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface EthStorageContract {
    function putBlob(bytes32 key, uint256 blobIdx, uint256 length) external payable;

    function get(bytes32 key, uint256 off, uint256 len) external view returns (bytes memory);

    function remove(bytes32 key) external;

    function upfrontPayment() external view returns (uint256);
}

// Large storage manager to support arbitrarily-sized data with multiple chunk
contract LargeStorageManager {
    struct Blob {
        uint256 idv; // 0 start
        uint256 length;
        bytes32 blobKey;
    }

    struct Chunk {
        uint256 chunkSize;
        bytes32 chunkHash;
        Blob[] blobs;
    }

    EthStorageContract public storageContract;
    mapping(bytes32 => Chunk[]) internal keyToChunk;

    constructor(address storageAddress) {
        storageContract = EthStorageContract(storageAddress);
    }

    function _preparePut(bytes32 key, uint256 chunkId) private {
        require(chunkId <= _countChunks(key), "must replace or append");
        if (chunkId < _countChunks(key)) {
            // replace, delete old blob
            Chunk storage chunk = keyToChunk[key][chunkId];
            uint256 length = chunk.blobs.length;
            for (uint8 i = 0; i < length; i++) {
                storageContract.remove(chunk.blobs[i].blobKey);
            }
            delete chunk.blobs;
        }
    }

    function _putChunk(
        bytes32 key,
        uint256 value,
        uint256 chunkId,
        bytes32 chunkHash,
        bytes32[] memory blobKeys,
        uint256[] memory blobLengths
    ) internal {
        require(blobKeys.length < 3 && blobKeys.length > 0, "invalid blob length");
        uint256 cost = storageContract.upfrontPayment();
        require(value >= cost * blobKeys.length, "insufficient balance");

        _preparePut(key, chunkId);

        Chunk storage chunk = keyToChunk[key][chunkId];
        // put blob
        uint256 size = 0;
        uint256 length = blobKeys.length;
        for (uint8 i = 0; i < length; i++) {
            storageContract.putBlob{value: cost}(blobKeys[i], i, blobLengths[i]);
            chunk.blobs.push(Blob(i, blobLengths[i], blobKeys[i]));
            size += blobLengths[i];
        }
        chunk.chunkSize = size;
        chunk.chunkHash = chunkHash;
    }

    function _getChunk(bytes32 key, uint256 chunkId) internal view returns (bytes memory, bool) {
        bytes memory data = new bytes(0);
        Chunk memory chunk = keyToChunk[key][chunkId];
        uint256 length = chunk.blobs.length;
        if (length < 1) {
            return (data, false);
        }

        for (uint8 i = 0; i < length; i++) {
            bytes memory temp = storageContract.get(chunk.blobs[i].blobKey, 0, chunk.blobs[i].length);
            data = bytes.concat(data, temp);
        }
        return (data, true);
    }

    function _chunkSize(bytes32 key, uint256 chunkId) internal view returns (uint256, bool) {
        if (_countChunks(key) == 0 || chunkId >= _countChunks(key)) {
            return (0, false);
        }
        uint256 size = keyToChunk[key][chunkId].chunkSize;
        return (size, true);
    }

    function _countChunks(bytes32 key) internal view returns (uint256) {
        return keyToChunk[key].length;
    }

    //     Returns (size, # of chunks).
    function _size(bytes32 key) internal view returns (uint256, uint256) {
        uint256 size = 0;
        uint256 chunkId = 0;

        while (true) {
            (uint256 chunkSize, bool found) = _chunkSize(key, chunkId);
            if (!found) {
                break;
            }

            size += chunkSize;
            chunkId++;
        }

        return (size, chunkId);
    }

    function _get(bytes32 key) internal view returns (bytes memory, bool) {
        (, uint256 chunkNum) = _size(key);
        if (chunkNum == 0) {
            return (new bytes(0), false);
        }

        bytes memory data = new bytes(0);
        for (uint256 chunkId = 0; chunkId < chunkNum; chunkId++) {
            (bytes memory temp, bool state) = _getChunk(key, chunkId);
            if (!state) {
                break;
            }
            data = bytes.concat(data, temp);
        }

        return (data, true);
    }

    // Returns # of chunks deleted
    function _remove(bytes32 key, uint256 chunkId) internal returns (uint256) {
        require(_countChunks(key) > 0, "the file has no content");

        for (uint256 i = _countChunks(key) - 1; i >= chunkId; i--) {
            Chunk storage chunk = keyToChunk[key][i];
            uint256 length = chunk.blobs.length;
            for (uint8 j = 0; j < length; j++) {
                storageContract.remove(chunk.blobs[j].blobKey);
            }
            keyToChunk[key].pop();
        }

        return chunkId;
    }

    function _removeChunk(bytes32 key, uint256 chunkId) internal returns (bool) {
        require(_countChunks(key) - 1 == chunkId, "only the last chunk can be removed");

        Chunk storage chunk = keyToChunk[key][chunkId];
        uint256 length = chunk.blobs.length;
        for (uint8 i = 0; i < length; i++) {
            storageContract.remove(chunk.blobs[i].blobKey);
        }
        keyToChunk[key].pop();
        return true;
    }

    function _chunkHash(bytes32 key, uint256 chunkId) internal view returns (bytes32) {
        if(_countChunks(key) == 0 || chunkId >= _countChunks(key)) {
            return bytes32(0);
        }
        return keyToChunk[key][chunkId].chunkHash;
    }

    function upfrontPayment() public view virtual returns (uint256) {
        return storageContract.upfrontPayment();
    }
}
