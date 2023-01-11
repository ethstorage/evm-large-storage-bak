// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./FlatDirectory.sol";

contract SimpleW3boxEVM {
    using Strings for uint256;

    struct File {
        uint256 time;
        bytes name;
        bytes fileType;
    }

    struct FilesInfo {
        File[] files;
        mapping(bytes32 => uint256) fileIds;
    }

    FlatDirectory public fileFD;

    address public owner;
    string public gateway;

    mapping(address => FilesInfo) fileInfos;

    constructor(string memory shortName) {
        owner = msg.sender;
        fileFD = new FlatDirectory(0);

        // https://0x7f87dcea4a43173f57c67cb80d28dbc388ba9ab9.arb-nova.w3link.io/
        gateway = string(abi.encodePacked(
                "https://",
                Strings.toHexString(uint256(uint160(address(fileFD))), 20),
                ".",
                shortName,
                '.w3link.io/'
            ));
    }

    function write(bytes memory name, bytes memory fileType, bytes calldata data) public payable {
        writeChunk(name, fileType, 0, data);
    }

    function writeChunk(bytes memory name, bytes memory fileType, uint256 chunkId, bytes calldata data) public payable {
        bytes32 nameHash = keccak256(name);
        FilesInfo storage info = fileInfos[msg.sender];
        if (info.fileIds[nameHash] == 0) {
            // first add file
            info.files.push(File(block.timestamp, name, fileType));
            info.fileIds[nameHash] = info.files.length;
        }

        fileFD.writeChunk{value: msg.value}(getNewName(msg.sender, name), chunkId, data);
    }

    function remove(bytes memory name) public returns (uint256) {
        bytes32 nameHash = keccak256(name);
        FilesInfo storage info = fileInfos[msg.sender];
        require(info.fileIds[nameHash] != 0, "File does not exist");

        uint256 lastIndex = info.files.length - 1;
        uint256 removeIndex = info.fileIds[nameHash] - 1;
        if (lastIndex != removeIndex) {
            File storage lastFile = info.files[lastIndex];
            info.files[removeIndex] = lastFile;
            info.fileIds[keccak256(lastFile.name)] = removeIndex + 1;
        }
        info.files.pop();
        delete info.fileIds[nameHash];
        return fileFD.remove(getNewName(msg.sender, name));
    }

    function getChunkHash(bytes memory name, uint256 chunkId) public view returns (bytes32) {
        return fileFD.getChunkHash(getNewName(msg.sender, name), chunkId);
    }

    function countChunks(bytes memory name) public view returns (uint256) {
        return fileFD.countChunks(getNewName(msg.sender, name));
    }

    function getNewName(address author,bytes memory name) public pure returns (bytes memory) {
        return abi.encodePacked(
            Strings.toHexString(uint256(uint160(author)), 20),
            '/',
            name
        );
    }

    function getUrl(bytes memory name) public view returns (string memory) {
        return string(abi.encodePacked(gateway, name));
    }

    function getAuthorFiles(address author)
        public view
        returns (
            uint256[] memory times,
            bytes[] memory names,
            bytes[] memory types,
            string[] memory urls
        )
    {
        uint256 length = fileInfos[author].files.length;
        times = new uint256[](length);
        names = new bytes[](length);
        types = new bytes[](length);
        urls = new string[](length);

        for (uint256 i; i < length; i++) {
            times[i] = fileInfos[author].files[i].time;
            names[i] = fileInfos[author].files[i].name;
            types[i] = fileInfos[author].files[i].fileType;
            urls[i] = getUrl(getNewName(author, names[i]));
        }
    }
}
