const TYPE_SWAP_REMOTE = 1
const TYPE_ADD_LIQUIDITY = 2
const TYPE_REDEEM_LOCAL_CALL_BACK = 3
const TYPE_WITHDRAW_REMOTE = 4
const TYPE_REDEEM_LOCAL_RESPONSE = 1
const TYPE_REDEEM_LOCAL_CALLBACK_RETRY = 2
const TYPE_SWAP_REMOTE_RETRY = 3
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
const DEBUG = false // Flag this if you want to print verbose

// chain ids
const ETHEREUM = 1, AVAX = 2, POLYGON = 3, BSC = 4, OPTIMISM = 5, ARBITRUM = 6, FANTOM = 7
const CHAIN_ID_TO_NAME: {[key:number]: string} = {
    [ETHEREUM]: "Eth",
    [AVAX]: "Avax",
    [POLYGON]: "Polygon",
    [BSC]: "Binance",
    [OPTIMISM]: "Optimism",
    [ARBITRUM]: "Arbitrum",
    [FANTOM]: "Fantom",
}
// pool/token ids
const DAI = 11, USDC = 22, MIM = 33, BUSD = 44, TETHER = 55
const POOL_ID_TO_NAME: {[key:number]: string} = {
    [USDC]: "usdc",
    [DAI]: "dai",
    [MIM]: "mim",
    [BUSD]: "busd ",
    [TETHER]: "tether",
}

const CHAINS = [ETHEREUM, BSC, AVAX, POLYGON, OPTIMISM, ARBITRUM, FANTOM]
const TOKENS = [BUSD, USDC, DAI, MIM, TETHER]

enum ActionType {
// data types
    SwapRemote,
    Stake,
    Unstake,
    GetStakedAmountLD,
    GetTotalAssetsMD
}
const TREASURY_ACTION_TYPE = {
    "TYPE_WITHDRAW": 1,
    "TYPE_ADD_OWNER": 2,
    "TYPE_DEL_OWNER": 3,
    "TYPE_SUPPORT_TOKEN": 4,
    "TYPE_DEL_PROPOSAL": 5,
    "TYPE_UPDATE_REQUIRED_NUM": 6,
    "TYPE_INVALID": 7,
}

export {
    TYPE_SWAP_REMOTE,
    TYPE_ADD_LIQUIDITY,
    TYPE_REDEEM_LOCAL_CALL_BACK,
    TYPE_WITHDRAW_REMOTE,
    TYPE_REDEEM_LOCAL_RESPONSE,
    TYPE_REDEEM_LOCAL_CALLBACK_RETRY,
    TYPE_SWAP_REMOTE_RETRY,
    ZERO_ADDRESS,
    TREASURY_ACTION_TYPE,
    DEBUG,
    ETHEREUM,
    BSC,
    AVAX,
    POLYGON,
    OPTIMISM,
    ARBITRUM,
    FANTOM,
    CHAIN_ID_TO_NAME,
    USDC,
    DAI,
    MIM,
    BUSD,
    TETHER,
    POOL_ID_TO_NAME,
    CHAINS,
    TOKENS,
    ActionType,
}
