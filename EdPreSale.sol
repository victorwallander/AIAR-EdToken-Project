pragma solidity ^0.4.24;


/**
 * @title ERC20 interface + Mint function
 * 
 */
contract ERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  function mint(address _to, uint256 _amount) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title OwnableWithAdmin 
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract OwnableWithAdmin {
  address public owner;
  address public adminOwner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
    adminOwner = msg.sender;
  }
  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Throws if called by any account other than the admin.
   */
  modifier onlyAdmin() {
    require(msg.sender == adminOwner);
    _;
  }

  /**
   * @dev Throws if called by any account other than the owner or admin.
   */
  modifier onlyOwnerOrAdmin() {
    require(msg.sender == adminOwner || msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

  /**
   * @dev Allows the current adminOwner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferAdminOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(adminOwner, newOwner);
    adminOwner = newOwner;
  }

}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function uint2str(uint i) internal pure returns (string){
      if (i == 0) return "0";
      uint j = i;
      uint length;
      while (j != 0){
          length++;
          j /= 10;
      }
      bytes memory bstr = new bytes(length);
      uint k = length - 1;
      while (i != 0){
          bstr[k--] = byte(48 + i % 10);
          i /= 10;
      }
      return string(bstr);
  }
 
  
}


/**
 * @title LockedCrowdsale
 * @notice Contract is payable and owner or admin can allocate tokens.
 * Tokens will be released in 3 steps / dates. 
 *
 *
 *
 */
contract LockedCrowdsale is OwnableWithAdmin {
  using SafeMath for uint256;

  uint256 private constant DECIMALFACTOR = 10**uint256(18);

  event FundsBooked(address backer, uint256 amount, bool isContribution);
  event LogTokenClaimed(address indexed _recipient, uint256 _amountClaimed, uint256 _totalAllocated, uint256 _grandTotalClaimed);
  event LogNewAllocation(address indexed _recipient, uint256 _totalAllocated);
  event LogOwnerAllocation(address indexed _recipient, uint256 _totalAllocated);
  event LogRemoveAllocation(address indexed _recipient, uint256 _tokenAmountRemoved);
   

  // Amount of tokens claimed
  uint256 public grandTotalClaimed = 0;

  

  // The token being sold
  ERC20 public token;

  // Address where funds are collected
  address public wallet;

  // How many weis one token costs 
  uint256 public rate;

  // Minimum weis one token costs 
  uint256 public minRate; 

  // Minimum buy in weis 
  uint256 public minWeiAmount = 100000000000000000; 

  // Amount of tokens Raised
  uint256 public tokensTotal = 0;

  // Max token amount
  uint256 public hardCap = 0;

  
  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;
  

  //Tokens will be released in 3 steps/dates
  uint256 public step1;
  uint256 public step2;
  uint256 public step3;

  // Buyers total allocation
  mapping (address => uint256) public allocationsTotal;

  // User total Claimed
  mapping (address => uint256) public totalClaimed;

  // List of allocation step 1
  mapping (address => uint256) public allocations1;

  // List of allocation step 2
  mapping (address => uint256) public allocations2;

  // List of allocation step 3
  mapping (address => uint256) public allocations3;

  //Buyers
  mapping(address => bool) public buyers;

  //ETHBuyers
  mapping(address => bool) public ETHBuyers;

  //Buyers who received all there tokens
  mapping(address => bool) public buyersReceived;

  //List of all addresses
  address[] public addresses;

  //Whitelist
  mapping(address => bool) public whitelist;
  
 
  constructor(uint256 _step1, uint256 _step2, uint256 _step3, uint256 _startTime, uint256 _endTime, address _wallet, ERC20 _token) public {
     
    require(_wallet != address(0));
    require(_token != address(0));

    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_step1 >= _endTime);
    require(_step2 >= _step1);
    require(_step3 >= _step2);

    startTime   = _startTime;
    endTime     = _endTime;
    step1       = _step1;
    step2       = _step2;
    step3       = _step3;

    wallet = _wallet;
    token = _token;
  }

  // -----------------------------------------
  // External interface
  // -----------------------------------------

  /**
   * @dev fallback function ***DO NOT OVERRIDE***
   */
  function () public payable  {

    //Check if msg sender value is more then 0
    require( msg.value > 0 );

    //Validate crowdSale
    require(_validCrowdsale());

    //Validate whitelisted
    require(isWhitelisted(msg.sender));

    //Wei sent
    uint256 _weiAmount = msg.value;

    //Minimum buy in wei 
    require(_weiAmount>minWeiAmount);

    //Calculate token amount to be created
    uint256 _tokenAmount = _calculateTokens(_weiAmount);

    //Check hardCap 
    require(_validateHardCap(_tokenAmount));

    //Mint tokens and transfer tokens to this contract. Then allocation the tokens to buyer.
    require(token.mint(this, _tokenAmount));

    //Allocate tokens
    _setAllocation(msg.sender, _tokenAmount);

    //This is a ETH purchase
    ETHBuyers[msg.sender] = true;

    //Increese token amount
    tokensTotal = tokensTotal.add(_tokenAmount);

    //Funds log function
    emit FundsBooked(msg.sender, _weiAmount, true);

    //Transfer funds to wallet
    _forwardFunds();

 
  }


  /**
    * @dev Set allocation buy admin
    * @param _recipient Buyers address
    * @param _tokenAmount Token amount
    */
  function setAllocation(address _recipient, uint256 _tokenAmount) onlyOwnerOrAdmin  public{
      require(_tokenAmount > 0);      
      require(_recipient != address(0)); 

      //Validate crowdSale
      require(_validCrowdsale());

      //Validate whitelisted
      require(isWhitelisted(_recipient)); 

      //Check hardCap 
      require(_validateHardCap(_tokenAmount));

      //Mint tokens and transfer tokens to this contract. Then allocation the tokens to buyer
      require(token.mint(this, _tokenAmount));

      //Allocate tokens
      _setAllocation(_recipient, _tokenAmount);    

      //Increese token amount
      tokensTotal = tokensTotal.add(_tokenAmount);  

      //Logg Allocation
      emit LogOwnerAllocation(_recipient, _tokenAmount);
  }

  /**
    * @dev Remove allocation
    * @param _recipient 
    *  
    */
  function removeAllocation(address _recipient) onlyOwner  public{         
      require(_recipient != address(0)); 
      require(totalClaimed[_recipient] == 0); //Check if user claimed tokens

      //Prevent ETH buyers to lose allocation
      require(!ETHBuyers[_recipient]);

      //_recipient total amount
      uint256 _tokenAmountRemoved = allocationsTotal[_recipient];

      //Decreese token amount
      tokensTotal = tokensTotal.sub(_tokenAmountRemoved);

      //Reset allocations
      allocations1[_recipient]      = 0; 
      allocations2[_recipient]      = 0; 
      allocations3[_recipient]      = 0;
      allocationsTotal[_recipient]  = 0; // Remove 

      //Set buyer to false
      buyers[_recipient] = false;


      emit LogRemoveAllocation(_recipient, _tokenAmountRemoved);
  }


 /**
   * @dev Set internal allocation 
   *  _buyer The adress of the buyer
   *  _tokenAmount Amount Allocated tokens + 18 decimals
   */
  function _setAllocation (address _buyer, uint256 _tokenAmount) internal{

      if(!buyers[_buyer]){
        //Add buyer to buyers list 
        buyers[_buyer] = true;

        //Add _buyer to addresses list
        addresses.push(_buyer);

        //Reset buyer allocation
        allocationsTotal[_buyer] = 0;

      }  

      //Add tokens to buyers allocation
      allocationsTotal[_buyer]  = allocationsTotal[_buyer].add(_tokenAmount); 

      //Spilt amount in 3
      uint256 splitAmount = allocationsTotal[_buyer].div(3);
      uint256 diff        = allocationsTotal[_buyer].sub(splitAmount+splitAmount+splitAmount);


      //Sale steps
      allocations1[_buyer]   = splitAmount;            // step 1 
      allocations2[_buyer]   = splitAmount;            // step 2
      allocations3[_buyer]   = splitAmount.add(diff);  // step 3 + diff


      //Logg Allocation
      emit LogNewAllocation(_buyer, _tokenAmount);

  }


  /**
    * @dev Return address available allocation
    * @param _recipient which address is applicable
    */
  function checkAvailableTokens (address _recipient) public view returns (uint256) {
    //Check if user have bought tokens
    require(buyers[_recipient]);

    uint256 _availableTokens = 0;

    if(now >= step1){
      _availableTokens = _availableTokens.add(allocations1[_recipient]);
    }
    if(now >= step2){
      _availableTokens = _availableTokens.add(allocations2[_recipient]);
    }
    if(now >= step3){
      _availableTokens = _availableTokens.add(allocations3[_recipient]);
    }

    return _availableTokens;
  }

  /**
    * @dev Transfer a recipients available allocation to their address
    * @param _recipients Array of addresses to withdraw tokens for
    */
  function distributeManyTokens(address[] _recipients) onlyOwnerOrAdmin public {
    for (uint256 i = 0; i < _recipients.length; i++) {

      //Check if address is buyer 
      //And if the buyer is not already received all the tokens
      if(buyers[_recipients[i]] && !buyersReceived[_recipients[i]]){
        distributeTokens( _recipients[i]);
      }
    }
  }

  /**
    * @dev Loop address and distribute tokens
    *
    */
  function distributeAllTokens() onlyOwner public {
    for (uint256 i = 0; i < addresses.length; i++) {

      //Check if address is buyer 
      //And if the buyer is not already received all the tokens
      if(buyers[addresses[i]] && !buyersReceived[addresses[i]]){
        distributeTokens( addresses[i]);
      }
            
    }
  }


  /**
    * @notice Withdraw available tokens
    *
    */
  function withdrawTokens() public {
    distributeTokens(msg.sender);
  }

  /**
    * @dev Transfer a recipients available allocation to _recipient
    *
    */
  function distributeTokens(address _recipient) public {
    //Check date
    require(now >= step1);
    //Check have bought tokens
    require( buyers[_recipient] );

    //
    bool _lastWithdraw = false;

    uint256 _availableTokens = 0;
    
    if(now >= step1  && now >= step2  && now >= step3 ){      

      _availableTokens = _availableTokens.add(allocations3[_recipient]); 
      _availableTokens = _availableTokens.add(allocations2[_recipient]);
      _availableTokens = _availableTokens.add(allocations1[_recipient]);

      //Reset all allocations
      allocations3[_recipient] = 0;
      allocations2[_recipient] = 0;
      allocations1[_recipient] = 0;

      //Step 3, all tokens should be received
      _lastWithdraw = true;

    } else if(now >= step1  && now >= step2 ){
      
      _availableTokens = _availableTokens.add(allocations2[_recipient]);
      _availableTokens = _availableTokens.add(allocations1[_recipient]); 

      //Reset step 1 & step 2 allocation
      allocations2[_recipient] = 0;
      allocations1[_recipient] = 0;


    }else if(now >= step1){

      _availableTokens = allocations1[_recipient];

      //Reset step 1 allocation
      allocations1[_recipient] = 0; 


    }

    require(_availableTokens>0);    

    //Check if contract has tokens
    require(token.balanceOf(this)>=_availableTokens);

    //Transfer tokens
    require(token.transfer(_recipient, _availableTokens));

    //Add claimed tokens to user totalClaimed
    totalClaimed[_recipient] = totalClaimed[_recipient].add(_availableTokens);

    //Add claimed tokens to grandTotalClaimed
    grandTotalClaimed = grandTotalClaimed.add(_availableTokens);

    emit LogTokenClaimed(_recipient, _availableTokens, allocationsTotal[_recipient], grandTotalClaimed);

    //If all tokens are received, add _recipient to buyersReceived
    //To prevent the loop to fail if user allready used the withdrawTokens
    if(_lastWithdraw){
      buyersReceived[_recipient] = true;
    }

  }


  // send ether to the fund collection wallet
  function _forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function _validCrowdsale() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    return withinPeriod;
  }
  

  function _validateHardCap(uint256 _tokenAmount) internal view returns (bool) {
      return tokensTotal.add(_tokenAmount) <= hardCap;
  }


  function _calculateTokens(uint256 _wei) internal view returns (uint256) {
    return _wei.mul(DECIMALFACTOR).div(rate);
  }


  function isCrowdsaleActive() public view returns (bool) {    
    return _validCrowdsale();
  }


  /**
   * @dev Update current rate
   * @param _rate How many weis one token costs
   * We need to be able to update the rate as the eth rate changes
   */ 
  function setRate(uint256 _rate) onlyOwnerOrAdmin public{
    require(_rate > minRate);
    rate = _rate;
  }


  function addToWhitelist(address _buyer) onlyOwnerOrAdmin public{
    require(_buyer != 0x0);     
    whitelist[_buyer] = true;
  }
  

  function addManyToWhitelist(address[] _beneficiaries) onlyOwnerOrAdmin public{
    for (uint256 i = 0; i < _beneficiaries.length; i++) {
      if(_beneficiaries[i] != 0x0){
        whitelist[_beneficiaries[i]] = true;
      }
    }
  }


  function removeFromWhitelist(address _buyer) onlyOwnerOrAdmin public{
    whitelist[_buyer] = false;
  }


  // @return true if buyer is whitelisted
  function isWhitelisted(address _buyer) public view returns (bool) {
      return whitelist[_buyer];
  }

  function getListOfAddresses() public onlyOwnerOrAdmin view returns (address[]) {    
    return addresses;
  }


  // Owner can transfer tokens that are sent here by mistake
  function refundTokens(address _recipient, ERC20 _token) public onlyOwner {
    uint256 balance = _token.balanceOf(this);
    require(_token.transfer(_recipient, balance));
  }


}


/**
 * @title EDPreSale
 * @notice Contract is payable and owner or admin can allocate tokens.
 * Only owner or admin can allocate tokens. Tokens will be minted to this contract for allocation.
 * Tokens will be released in 3 steps / dates. 
 * User will use withdrawTokens to receive tokens to wallet. 
 * Users needs to be whitelisted
 *
*/
contract EDPreSale is LockedCrowdsale {
  constructor(
    uint256 _step1, 
    uint256 _step2, 
    uint256 _step3, 
    uint256 _startTime, 
    uint256 _endTime,  
    address _wallet, 
    ERC20 _token
  ) public LockedCrowdsale(_step1, _step2, _step3, _startTime, _endTime,  _wallet, _token) {

    // Initial rate
    //What one token cost in wei
    rate = 305000000000000;   

    // Initial minimum rate
    // rate can't be set below this
    minRate = 200000000000000;   

    // 75,000,000 tokens
    hardCap = 75000000 * (10**uint256(18)); 

  }
}
