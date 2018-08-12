import React, { Component } from 'react';
import { AccountData, ContractData, ContractForm } from 'drizzle-react-components';
import rega from '../../WALT.png';
import BalanceData  from './BalanceData.js';
import SmartContainer from './SmartContainer.js';

class Home extends Component {
  constructor(props, context) {
    super(props);
    console.log(props);
    console.log(context);

    this.addresses = {
      TokenPool : context.drizzle.contracts.TokenPool._address,
      TokenContainer: context.drizzle.contracts.TokenContainer._address,
      TokenLoyalty: context.drizzle.contracts.TokenLoyalty._address
    };
    this.value = {
      value: context.drizzle.web3.utils.toWei("1")
    };
    this.paymentAmount = context.drizzle.web3.utils.toWei("0.1");
    this.debitAmount = 100;
  }
  renderSetSender(receiver, sender) {
    return (
      <SmartContainer accountIndex="0" ownerOnly init>
        <h3>{sender} Address</h3>
        <p>{this.addresses[sender]}</p>
        <h3>{receiver} Address</h3>
        <p>{this.addresses[receiver]}</p>
        <h3>Connectors</h3>
        <p><ContractData contract={receiver} method="connectors" methodArgs={[this.addresses[sender]]} /></p>
        <h3>{receiver} : setSender ( {sender} )</h3>
        <ContractForm contract={receiver} method="setSender" labels={[sender]} />

        <br/><br/>
      </SmartContainer>
    )
  }
  renderInit() {
    return (
      <SmartContainer accountIndex="0" ownerOnly init>
        <h3>Number of pools</h3>
        <p><ContractData contract="TokenPool" method="getPoolSize" /></p>
        <h3>TokenPool : init ( )</h3>
        <ContractForm contract="TokenPool" method="init" />
        <br/><br/>
      </SmartContainer>
    )
  }
  renderInfo(t) {
    return (
     <div>
        <h2>Smart Contract Information</h2>
        <h3>Current Account</h3>
        <AccountData accountIndex="0" units="ether" precision="4" />
        <h3>Loyalty Token Address</h3>
        <p><ContractData contract="ERC20Adapter" method="root" /></p>
        <p><ContractData contract="TokenContainer" method="balanceOf" methodArgs={[this.props.accounts[0]]} /> <ContractData contract="TokenContainer" method="symbol" hideIndicator /> </p>
        <p><BalanceData contract="ERC20Adapter" method="balanceOf" accountIndex="0" units="ether" precision="4" /> Ether </p>
        <p><ContractData contract="TokenLoyalty" method="getBalance" /> Wei </p>
        <h3>Loyalty Total Supply</h3>
        <p><ContractData contract="TokenContainer" method="totalSupply" /> </p>
        <h3>Current Token State [ Claim : 1023, Paid : 1022 ]</h3>
        <p><ContractData contract="TokenPool" method="getState" methodArgs={[4]} /> </p>
        <p><ContractData contract="TokenContainer" method="getNFTState" methodArgs={[4]} /> </p>
        <h3>Current Token Sub Pool ID</h3>
        <p><ContractData contract="TokenPool" method="getSubPool" methodArgs={[4]} /> </p>
        <h3>Current Token Payment Status</h3>
        <p><ContractData contract="TokenLoyalty" method="checkPayment" methodArgs={[4]} /> </p>
        <h3>Current Sub Pool ID</h3>
        <p><ContractData contract="TokenLoyalty" method="subPoolId" /> </p>
        <h3>Loyalty Token Owner</h3>
        <p><ContractData contract="TokenLoyalty" method="owner" /></p>
        {t && 
          <div>
            <h3>Current Sub Pools</h3>
            <ContractData contract="TokenLoyalty" method="getCurrentSubPoolExtension" />
          </div>
        }
        <br/><br/>
      </div>
    )
  }
  render() {
    return (
      <main className="container">
       
        <div className="pure-g">
          <div className="pure-u-1-1 header">
            <img src={rega} alt="drizzle-logo" />
            <h1>REGA Loyalty Token</h1>
            <h3>W.A.L.T. Smart Contracts &nbsp;<small>v 0.0.1</small></h3>

            <br/><br/>
          </div>

          <SmartContainer accountIndex="0" ownerOnly>
            <h2>Test check list</h2>
            <label>
              <input type="checkbox" name="ether_transfer" /> &nbsp;
              01&nbsp;-&nbsp;Create loyalty token &nbsp;
            </label>
            <br/>
            <label>
              <input type="checkbox" name="rst_transfer" /> &nbsp;
              02&nbsp;-&nbsp;Activate loyalty token for member address&nbsp;
            </label>
            <br/>
            <label>
              <input type="checkbox" name="apply" /> &nbsp;
              04&nbsp;-&nbsp;Provide funding to sub pool &nbsp;
            </label>
            
            <br/><br/>
          </SmartContainer>

         <SmartContainer accountIndex="0" ownerOnly init>
            {this.renderInfo(false)}
          </SmartContainer>

          {this.renderSetSender("TokenContainer", "TokenPool")}
          {this.renderSetSender("TokenPool", "TokenLoyalty")}
          {this.renderInit()}
        
          <SmartContainer accountIndex="0">
            {this.renderInfo(true)}
          </SmartContainer>

          <SmartContainer accountIndex="0" ownerOnly>
            <h2>Create</h2>
            <p>The first step is creating Loyalty Token</p>
            <h3>Create Token</h3>
            <ContractForm contract="TokenLoyalty" method="create" labels={['Member Address', 'Client ID']} />
            <br/><br/>
          </SmartContainer>

          <SmartContainer accountIndex="0" ownerOnly>
            <h2>Activate</h2>
            <p>Activate loyalty token for member address</p>
            
            <h3>Activate token</h3>
            <ContractForm contract="TokenLoyalty" method="activate" labels={['Token ID']} />
            
            <br/><br/>
          </SmartContainer>

          <SmartContainer accountIndex="0" ownerOnly>
            <h2>Funding</h2>
            <p>Provide Funding to Sub Pool</p>
            <h3>Sub Pool Id</h3>
            <ContractData contract="TokenLoyalty" method="subPoolId" />
            <h3>Payment Amount</h3>
            <p>{this.paymentAmount}</p>
            <h3>Debit Amount</h3>
            <p>{this.debitAmount}</p>
            <h3>Value to send</h3>
            <p>{this.value.value}</p>
            
            <h3>Fund</h3>
            <ContractForm contract="TokenLoyalty" method="fund" labels={['Sub Pool ID', 'Payment Amount', 'Debit Value']} sendArgs={this.value}/>

            <br/><br/>
          </SmartContainer>

          
           <SmartContainer accountIndex="0" notOwnerOnly bizProcessId="21">
            <h2>Receive</h2>
            <p>Now receive claim payment</p>
            
            <h3>PAYMENT</h3>
            <ContractForm contract="TokenLoyalty" method="payment" labels={['Token ID']}/>

            <br/><br/>
          </SmartContainer>

        </div>
      </main>
    )
  }
}

export default Home
