// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

///@notice adapted from https://solidity-by-example.org/app/iterable-mapping/


library IterableMapping {

    struct UintToUintMap {
        uint256[] keys;
        mapping(uint256 => uint256) values;
        mapping(uint256 => uint256) indexOf;
        mapping(uint256 => bool) inserted;
    }

    function get(UintToUintMap storage map, uint256 index) public view returns (uint256) {
        return map.values[index];
    }

    function getKeyAtIndex(UintToUintMap storage map, uint256 index) public view returns (uint256) {
        return map.keys[index];
    }

    function size(UintToUintMap storage map) public view returns (uint256) {
        return map.keys.length;
    }

    function set(UintToUintMap storage map, uint256 key, uint256 value) public {
        if (map.inserted[key]) {
            map.values[key] = value;
        }
        else {
            map.inserted[key] = true;
            map.values[key] = value;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }

    function remove(UintToUintMap storage map, uint256 key) public {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.values[key];

        uint index = map.indexOf[key];
        uint lastIndex = map.keys.length - 1;
        uint256 lastKey = map.keys[lastIndex];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.keys[index] = lastKey;
        map.keys.pop();
    }    



}