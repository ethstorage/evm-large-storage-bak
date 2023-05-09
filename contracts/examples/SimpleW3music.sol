// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./FlatDirectory2.sol";

contract W3MusicNFT is ERC721Enumerable('W3MUSIC', 'MUSIC'), FlatDirectory(0) {
    struct MusicInfo {
        uint256 createTime;
        address author;
        bytes fileName;
        bytes musicName;
        bytes describe;
        bytes cover;
    }
    mapping(uint256 => MusicInfo) musicInfos;

    function mint(
        address author_,
        bytes memory fileName_,
        bytes memory musicName_,
        bytes memory describe_,
        bytes memory cover_
    ) public {
        require(msg.sender == owner, "must from owner");
        uint256 tokenId = totalSupply;
        _safeMint(author_, tokenId);
        musicInfos[tokenId] = MusicInfo(block.timestamp, author_, fileName_, musicName_, describe_, cover_);
    }

    function getAuthorMusics(address author)
        public view
        returns (
            uint256[] memory ids,
            uint256[] memory times,
            address[] memory authors,
            bytes[] memory fileNames,
            bytes[] memory names,
            bytes[] memory describes,
            bytes[] memory covers
        )
    {
        uint256 length = ERC721.balanceOf(author);
        ids = new uint256[](length);
        times = new uint256[](length);
        authors = new address[](length);
        fileNames = new bytes[](length);
        names = new bytes[](length);
        describes = new bytes[](length);
        covers = new bytes[](length);
        for (uint256 i; i < length; i++) {
            uint256 tokenId = _ownedTokens[author][i];
            ids[i] = tokenId;
            times[i] = musicInfos[tokenId].createTime;
            authors[i] = musicInfos[tokenId].author;
            fileNames[i] = musicInfos[tokenId].fileName;
            names[i] = musicInfos[tokenId].musicName;
            describes[i] = musicInfos[tokenId].describe;
            covers[i] = musicInfos[tokenId].cover;
        }
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        MusicInfo memory music = musicInfos[tokenId];
        if(music.createTime <= 0){
            return 'The token does not exist!';
        }
        return string(abi.encodePacked(
                '{',
                '"name":"', music.musicName, '",',
                '"describe":"', music.describe, '",',
                '"fileName":"', music.fileName, '",',
                '"cover":"', music.cover, '",',
                '"time":"', music.createTime, '",',
                '"author":"', music.author, '",',
                '}'
            ));
    }

    function play(uint256 tokenId) external view returns (bytes memory) {
        MusicInfo memory music = musicInfos[tokenId];
        if(music.createTime <= 0){
            return bytes('The token does not exist!');
        }
        return abi.encodePacked(
            getHeader(),
            '<style>.nft-bg{background-size:cover;background-image: url("../../', getPathName(music.author, music.cover), '");}</style></head>',
            '<body><div class="nft nft-bg"><div class="cover">',
            '<p class="text">', music.musicName, '</p>',
            '<p class="describe">', music.describe, '</p>',
            '<audio controls src="../../', getPathName(music.author, music.fileName), '" />',
            '</div></div></body></html>'
        );
    }

    function getHeader() private pure returns (string memory) {
        return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>W3Music</title><style>::-webkit-scrollbar {width: 5px;}::-webkit-scrollbar-track {background: #fff;}::-webkit-scrollbar-thumb {background: #555;}::-webkit-scrollbar-thumb:hover {background: #222;}body{background-image: linear-gradient(to right, pink, skyblue);}.nft {position: absolute;top: 0;bottom: 0;left: 0;right: 0;margin: auto;width: 380px;height: 500px;border-radius: 25px;box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2), 0 6px 20px 0 rgba(0, 0, 0, 0.19);}.cover {display: flex;flex-flow: column;justify-content: space-between;align-items: center;padding: 15px;width: 350px;height: 470px;border-radius: 25px;background-color: rgba(255, 255, 255, 0.4);}.text {font-size: 15px;line-height: 15px;font-weight: bold;color: #000000;}.describe {font-size: 13px;line-height: 20px;color: #212121;flex-grow: 2;overflow: auto;}</style>';
    }

    function getPathName(address author, bytes memory name) public pure returns (bytes memory) {
        return abi.encodePacked(
            Strings.toHexString(uint256(uint160(author)), 20), '-', name
        );
    }
}

contract SimpleW3Music {

    W3MusicNFT public w3Music;

    mapping(bytes => bool) public isExist;
    mapping(address => bytes[]) public userMusics;
    mapping(address => bytes[]) public userCovers;


    constructor() {
        w3Music = new W3MusicNFT();
    }

    function mint(bytes memory fileName_, bytes memory musicName_, bytes memory describe_, bytes memory cover_) public {
        w3Music.mint(msg.sender, fileName_, musicName_, describe_, cover_);
    }

    function writeChunk(uint256 fileType, uint256 chunkId, bytes memory name, bytes calldata data) public payable virtual {
        bytes memory pathName = w3Music.getPathName(msg.sender, name);
        w3Music.writeChunk{value: msg.value}(pathName, chunkId, data);
        if(!isExist[pathName]) {
            if(fileType == 0) {
                userMusics[msg.sender].push(name);
            } else {
                userCovers[msg.sender].push(name);
            }
            isExist[pathName] = true;
        }
    }

    function getChunkHash(bytes memory name, uint256 chunkId) public view returns (bytes32) {
        return w3Music.getChunkHash(w3music.getPathName(msg.sender, name), chunkId);
    }

    function countChunks(bytes memory name) public view returns (uint256) {
        return w3Music.countChunks(w3music.getPathName(msg.sender, name));
    }

    function remove(bytes memory name) public virtual returns (uint256) {
        return w3Music.remove(name);
    }

    function getMusics() public view returns (bytes[] memory fileNames) {
        return userMusics[msg.sender];
    }

    function getCovers() public view returns (bytes[] memory fileNames) {
        return userCovers[msg.sender];
    }
}
