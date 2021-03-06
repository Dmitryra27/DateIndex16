CREATE OR REPLACE FUNCTION
    `blockchain-etl-internal.ethereum_ens.parse_Registrar0_event_NewBid`(data STRING, topics ARRAY<STRING>)
    RETURNS STRUCT<`hash` STRING, `bidder` STRING, `deposit` STRING>
    LANGUAGE js AS """
    var abi = {"anonymous": false, "inputs": [{"indexed": true, "name": "hash", "type": "bytes32"}, {"indexed": true, "name": "bidder", "type": "address"}, {"indexed": false, "name": "deposit", "type": "uint256"}], "name": "NewBid", "type": "event"}

    var interface_instance = new ethers.utils.Interface([abi]);

    // A parsing error is possible for common abis that don't filter by contract address. Event signature is the same
    // for ABIs that only differ by whether a field is indexed or not. E.g. if the ABI provided has an indexed field
    // but the log entry has this field unindexed, parsing here will throw an exception.
    try {
      var parsedLog = interface_instance.parseLog({topics: topics, data: data});
    } catch (e) {
        return null;
    }

    var parsedValues = parsedLog.values;

    var transformParams = function(params, abiInputs) {
        var result = {};
        if (params && params.length >= abiInputs.length) {
            for (var i = 0; i < abiInputs.length; i++) {
                var paramName = abiInputs[i].name;
                var paramValue = params[i];
                if (abiInputs[i].type === 'address' && typeof paramValue === 'string') {
                    // For consistency all addresses are lower-cased.
                    paramValue = paramValue.toLowerCase();
                }
                if (ethers.utils.Interface.isIndexed(paramValue)) {
                    paramValue = paramValue.hash;
                }
                if (abiInputs[i].type === 'tuple' && 'components' in abiInputs[i]) {
                    paramValue = transformParams(paramValue, abiInputs[i].components)
                }
                result[paramName] = paramValue;
            }
        }
        return result;
    };

    var result = transformParams(parsedValues, abi.inputs);

    return result;
"""
OPTIONS
  ( library="gs://blockchain-etl-bigquery/ethers.js" );