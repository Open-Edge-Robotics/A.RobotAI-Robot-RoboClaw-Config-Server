package contracts

import _ "embed"

// RuntimeContractJSON embeds the vendored canonical runtime contract so CLI
// commands can inspect field metadata and secret env keys offline.
//
//go:embed runtime-contract.json
var RuntimeContractJSON []byte
