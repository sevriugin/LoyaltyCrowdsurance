import TokenLoyalty from './../build/contracts/TokenLoyalty.json'
import ERC20Adapter from './../build/contracts/ERC20Adapter.json'
import TokenContainer from './../build/contracts/TokenContainer.json'
import TokenPool from './../build/contracts/TokenPool.json'

const drizzleOptions = {
  web3: {
    block: false,
    fallback: {
      type: 'ws',
      url: 'ws://127.0.0.1:7545'
    }
  },
  contracts: [
    ERC20Adapter,
    TokenLoyalty,
    TokenContainer,
    TokenPool
  ],
  events: {
    TokenLoyalty: ['Created','SPExtension', 'Error', 'Added', 'Activated', 'Funded', 'Paid'],
    TokenContainer: ['AddToken', 'RemoveToken', 'Transfer', 'AddValue', 'RemoveValue', 'SetLevel', 'IncreaseLevel','SenderUpdate'],
    TokenPool: ['InsertPool', 'DistributeValue','SecondTierCall', 'ShortOfFunds', 'PaymentValue','SenderUpdate']
  },
  polls: {
    accounts: 1500
  }
}

export default drizzleOptions