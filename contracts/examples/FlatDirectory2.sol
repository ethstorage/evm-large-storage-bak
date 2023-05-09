// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC5018.sol";

contract FlatDirectory is ERC5018 {
    mapping(bytes4 => bytes) public methodToFiles;

    constructor(uint8 slotLimit) ERC5018(slotLimit) {}

    function resolveMode() external pure virtual returns (bytes32) {
        return "auto";
    }

    fallback(bytes calldata data) external payable returns (bytes memory) {
        // looks like return data does not work, use assembly
        bytes memory fileName = methodToFiles[convertBytesToBytes4(data)];
        (bytes memory content,) = read(fileName);
        StorageHelper.returnBytesInplace(content);
    }

    receive() external payable {
    }

    function getMethodId(bytes memory fileName) public pure returns(bytes4) {
        bytes memory method = abi.encodePacked(fileName, '()');
        return bytes4(keccak256(method));
    }

    function convertBytesToBytes4(bytes memory inBytes) public pure returns (bytes4 outBytes4) {
        if (inBytes.length == 0) {
            return 0x0;
        }
        assembly {
            outBytes4 := mload(add(inBytes, 32))
        }
    }

    function writeChunk(bytes memory name, uint256 chunkId, bytes calldata data) public payable virtual override {
        super.writeChunk(name, chunkId, data);
        methodToFiles[getMethodId(name)] = name;
    }
}
